module KoL.Http where

-- TODO: Merge with HttpLowlevel or at least restructure

import Prelude
import Logging
import KoL.HttpLowlevel
import KoL.Util
import KoL.UtilTypes
import Control.Concurrent
import Control.Exception
import Control.Monad
import Data.IORef
import Data.List (intercalate)
import Data.Time
import Data.Time.Clock.POSIX
import Network.URI
import Text.JSON
import qualified Data.ByteString.Char8

getHTTPFileData url = do
	(_, body, _, _) <- doHTTPreq (mkreq True kolproxy_version_string Nothing (mkuri url) Nothing True)
	return $ Data.ByteString.Char8.unpack body

postHTTPFileData url params = do
	(_, body, _, _) <- doHTTPreq (mkreq True kolproxy_version_string Nothing (mkuri url) (Just params) True)
	return $ Data.ByteString.Char8.unpack body

parseUriServerBugWorkaround rawuri = do
	let remapper x
		| (x == ' ') = '+'
		| otherwise = x
	case parseURIReference rawuri of
		Just z -> return $ Just z
		_ -> do -- Workaround for broken KoL redirect, e.g. trade counter-offer doesn't urlencode()
			let newx = map remapper rawuri
			putInfoStrLn $ "KOL SERVER BUG: parse failure, invalid URL received from server: " ++ (show rawuri) ++ " (shout at Jick or CDMoyer)"
			putInfoStrLn $ "  using " ++ (show newx) ++ " instead"
			return $ parseURIReference newx

-- TODO: combine these three
internalKolHttpsRequest url params cu _noredirect = do
	let (cucookie, useragent, host, _getconn) = cu
	let reqabsuri = url `relativeTo` host
	(effuri, body, hdrs, code) <- doHTTPSreq (mkreq True useragent cucookie reqabsuri params True)
	let addheaders = hdrs -- filter (\(x, _y) -> x == "Set-Cookie") hdrs
	return (body, effuri, addheaders, code)

internalKolRequest url params cu noredirect = do
	let (cucookie, useragent, host, getconn) = cu
	let reqabsuri = url `relativeTo` host
-- 	putDebugStrLn $ "single-req " ++ show absuri
	(effuri, body, hdrs, code) <- doHTTPreq (mkreq True useragent cucookie reqabsuri params True)

	if noredirect
		then return (body, effuri, hdrs, code)
		else case (code >= 300 && code < 400) of
			True -> do
				putWarningStrLn $ "Redirecting from internalKolRequest"
				case lookup "Location" hdrs of
					Just lochdruri -> do
						cookie <- case lookup "Set-Cookie" hdrs of
							Just hdrstr -> do
								let cookie = takeWhile (/= ';') hdrstr
								putDebugStrLn $ "set-cookie_single: " ++ cookie
								return $ Just cookie
							Nothing -> return cucookie
						putDebugStrLn $ "  singlereq gotpage: " ++ show effuri
						putDebugStrLn $ "    hdrs: " ++ show hdrs
						putDebugStrLn $ "    constructed cookie: " ++ show cookie
						let addheaders = filter (\(x, _) -> x == "Set-Cookie") hdrs
						case parseURI lochdruri of
							Nothing -> do
								Just to <- parseUriServerBugWorkaround lochdruri
-- 								putDebugStrLn $ "--> redirected " ++ (show url) ++ " -> " ++ (show to)
								(text, effurl, headers, c) <- internalKolRequest to Nothing (cookie, useragent, host, getconn) noredirect
								return (text, effurl, addheaders ++ headers, c)
							Just to -> do
-- 								putDebugStrLn $ "==> redirected " ++ (show url) ++ " -> " ++ (show to)
								(text, effurl, headers, c) <- internalKolRequest to Nothing (cookie, useragent, host, getconn) noredirect
								return (text, effurl, addheaders ++ headers, c)
					_ -> throwIO $ InternalError $ "Error parsing redirect: No location header"
			_ -> return (body, effuri, hdrs, code)

load_api_status_to_mv_mkapixf ref = do
	try $ internalKolRequest_pipelining ref (mkuri $ "/api.php?what=status,inventory&for=kolproxy+" ++ kolproxy_version_number ++ "+by+Eleron&format=json") Nothing False

load_api_status_to_mv ref mv apixf = do
	apires <- (try $ do
		let xf = case apixf of
			Right (xf, _) -> xf
			Left err -> throwIO (err :: SomeException)
		(xraw, xuri, _, _) <- xf
		jsobj <- case uriPath xuri of
			"/api.php" -> do
				let x = Data.ByteString.Char8.unpack $ xraw
				case decodeStrict x of
					Ok jsobj -> return jsobj
					Error err -> do
						t <- getPOSIXTime
						writeFile ("logs/api/invalid-api-result-" ++ show t ++ ".json") x
						throwIO $ ApiPageException err
			"/login.php" -> throwIO $ NotLoggedInException
			"/maint.php" -> throwIO $ NotLoggedInException
			"/afterlife.php" -> throwIO $ InValhallaException
			_ -> do
				putWarningStrLn $ "got uri: " ++ (show xuri) ++ " when raw-getting API"
				throwIO $ UrlMismatchException "/api.php" xuri
		return jsobj)
	writeIORef (latestRawJson_ $ sessionData $ ref) (Just apires)
	case apires of
		Right js -> writeIORef (latestValidJson_ $ sessionData $ ref) (Just js)
		_ -> return ()
	putMVar mv apires

internalKolRequest_pipelining ref uri params should_invalidate_cache = do
-- 	putDebugStrLn $ "pipeline-req " ++ show uri
	let host = hostUri_ $ connection $ ref

	curjsonmv <- if should_invalidate_cache
		then do
			newmv <- newEmptyMVar
			writeIORef (jsonStatusPageMVarRef_ $ sessionData $ ref) newmv
			return newmv
		else readIORef (jsonStatusPageMVarRef_ $ sessionData $ ref)
	retrieval_start <- getCurrentTime
	slowconn <- readIORef $ use_slow_http_ref_ $ globalstuff_ $ ref
	let (reqabsuri, r) = mkreq slowconn (useragent_ $ connection $ ref) (cookie_ $ connection $ ref) (uri `relativeTo` host) params True
	mv_x <- newEmptyMVar
	writeChan (getconn_ $ connection $ ref) (reqabsuri, r, mv_x, ref)

	when should_invalidate_cache $ do
		apixf <- load_api_status_to_mv_mkapixf ref
		forkIO_ "HTTP:load_api_status_to_mv" $ load_api_status_to_mv ref curjsonmv apixf

	mv_val <- newEmptyMVar
	forkIO_ "HTTP:mv_val" $ do
		putMVar mv_val =<< (try $ do
			(retabsuri, body, hdrs, code, _) <- do
				x <- (readMVar mv_x) `catch` (\e -> do
					-- TODO: when does this happen?
					-- TODO: make it not happen
					putWarningStrLn $ "httpreq read exception for " ++ (uriPath reqabsuri) ++ ": " ++ (show (e :: SomeException))
					throwIO e)
				case x of
					Right rx -> return rx
					Left e -> throwIO $ HttpRequestException reqabsuri e
			retrieval_end <- getCurrentTime
			prev_retrieval_end <- readIORef (lastRetrieve_ $ connection $ ref)
			writeIORef (lastRetrieve_ $ connection $ ref) retrieval_end
			let showurl = case params of
				Nothing -> show uri
				Just p -> show uri ++ " " ++ show p
			log_retrieval ref showurl (max retrieval_start prev_retrieval_end) retrieval_end

			case (code >= 300 && code < 400) of
				True -> do
					let Just lochdruri = lookup "Location" hdrs
					let addheaders = filter (\(x, _y) -> (x == "Set-Cookie" || x == "Location")) hdrs
					-- TODO: respect new cookie header here?
					case parseURI lochdruri of
						Nothing -> do
							Just to <- parseUriServerBugWorkaround lochdruri
-- 							putDebugStrLn $ "--> local redirected " ++ (show retabsuri) ++ " -> " ++ (show to)
							(y, mvy) <- internalKolRequest_pipelining ref to Nothing should_invalidate_cache
							(a, b, c, d) <- y
							themv <- mvy
							return ((a, b, addheaders ++ c, d), themv)
						Just to -> do
							putDebugStrLn $ "==> remote redirected " ++ (show retabsuri) ++ " => " ++ (show to)
							-- TODO: make new getconn and use pipelining
							(a, b, c, d) <- internalKolRequest to Nothing (cookie_ $ connection $ ref, useragent_ $ connection $ ref, host, Nothing) False
							return ((a, b, c, d), curjsonmv)
				_ -> return ((body, retabsuri, hdrs, code), curjsonmv))

	let xf = do
		x <- readMVar mv_val
		case x of
			Right (rx, _) -> return rx
			Left e -> throwIO (e :: SomeException)

	let mvf = do
		x <- readMVar mv_val
		case x of
			Right (_, mv) -> return mv
			Left e -> throwIO (e :: SomeException)

	return (xf, mvf)

login (login_useragent, login_host) name pass = do
	(text, _effuri, _headers, _code) <- internalKolRequest (mkuri "/") Nothing (Nothing, login_useragent, login_host, Nothing) False
	challenge <- case matchGroups "<input type=hidden name=challenge value=\"([0-9a-f]*)\">" (Data.ByteString.Char8.unpack text) of
		[[challenge]] -> return challenge
		_ -> throwIO $ NetworkError "No challenge found on login page. Down for maintenance?"
	let response = get_md5 (pass ++ ":" ++ challenge)
	let p_sensitive = [("loginname", name), ("challenge", challenge), ("response", response), ("secure", "1"), ("loggingin", "Yup.")]
	(_pt, _effuri, allhdrs, _code) <- internalKolRequest (mkuri "/login.php") (Just p_sensitive) (Nothing, login_useragent, login_host, Nothing) True
	let hdrs = filter (\(x, _y) -> (x == "Set-Cookie" || x == "Location")) allhdrs
	let new_cookie = case filter (\(a, _b) -> a == "Set-Cookie") hdrs of
		[] -> Nothing
		(x:xs) -> Just $ intercalate "; " (map ((takeWhile (/= ';')) . snd) (x:xs)) -- TODO: Make readable
	return new_cookie
