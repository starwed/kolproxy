module Logging where

import Prelude
import KoL.Util
import KoL.UtilTypes
import Control.Applicative
import Control.Concurrent
import Control.Exception
import Control.Monad
import Data.IORef
import Data.Time
import Network.URI
import System.IO
import Text.JSON
import Text.Printf
import qualified Data.Map
import qualified Data.ByteString.Char8

data LogItem = LogItem {
	time :: ZonedTime,
	apiStatusBefore :: Either SomeException (JSObject JSValue),
	apiStatusAfter :: Either SomeException (JSObject JSValue),
	stateBefore :: Maybe StateType,
	stateAfter :: Maybe StateType,
	sessionId :: String,
	requestedUri :: URI,
	parameters :: Maybe [(String, String)],
	retrievedUri :: URI,
	pageText :: Data.ByteString.Char8.ByteString
}

doLOGGING_DEBUG _ = return ()
-- doLOGGING_DEBUG x = putStrLn $ "LOGGING DEBUG: " ++ x

holdit ref action = writeChan (getlogchan ref) action

print_log_msg ref _file logdetails = do
	doLOGGING_DEBUG $ "print_log_msg start: " ++ (show $ time $ logdetails) ++ " | " ++ (show $ retrievedUri $ logdetails)
	doDbLogAction ref $ \db -> do
		doLOGGING_DEBUG $ "print_log_msg logaction: " ++ (show $ time $ logdetails) ++ " | " ++ (show $ retrievedUri $ logdetails)
-- 		putStrLn $ "writing to log db."
		let showstate s = case s of
			Just (_requestmap, _sessionmap, charmap, ascmap, daymap) -> Data.ByteString.Char8.pack $ show [("character", charmap), ("ascension", ascmap), ("day", daymap)]
			_ -> throw $ InternalError $ "Invalid state while logging"
		do_db_query_ db "INSERT INTO pageloads(time, statusbefore, statusafter, statebefore, stateafter, sessionid, requestedurl, parameters, retrievedurl, pagetext) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?);" [
			Just $ Data.ByteString.Char8.pack $ show $ time $ logdetails,
			case apiStatusBefore logdetails of
				Right x -> Just $ Data.ByteString.Char8.pack $ encodeStrict $ x
				_ -> Nothing,
			case apiStatusAfter logdetails of
				Right x -> Just $ Data.ByteString.Char8.pack $ encodeStrict $ x
				_ -> Nothing,
			Just $ showstate (stateBefore $ logdetails),
			Just $ showstate (stateAfter $ logdetails),
			Just $ Data.ByteString.Char8.pack $ sessionId $ logdetails,
			Just $ Data.ByteString.Char8.pack $ show $ requestedUri $ logdetails,
			Data.ByteString.Char8.pack <$> show <$> (parameters $ logdetails),
			Just $ Data.ByteString.Char8.pack $ show $ retrievedUri $ logdetails,
			Just $ pageText $ logdetails]
		doLOGGING_DEBUG $ "print_log_msg logactiondone: " ++ (show $ time $ logdetails) ++ " | " ++ (show $ retrievedUri $ logdetails)
	doLOGGING_DEBUG $ "print_log_msg alldone: " ++ (show $ time $ logdetails) ++ " | " ++ (show $ retrievedUri $ logdetails)

appendline ref whichh msg = holdit ref $ do
	hPutStrLn (whichh $ globalstuff_ $ ref) msg

log_file_retrieval ref url params = appendline ref h_files_downloaded_ $ (show url) ++ "  " ++ (show params)

internal_log_time_msg ref msg = appendline ref h_timing_log_ msg

diffms before now = fromRational $ 1000 * toRational (diffUTCTime now before) :: Double

--lua_log_line ref msg action = do
--	start <- getCurrentTime
---- 	x <- log_time_interval ref ("lua:" ++ msg) $ action
--	x <- action
--	end <- getCurrentTime
--	appendline ref h_lua_log_ $ printf "[%8.1fms] %s" (diffms start end) msg
--	return x
lua_log_line _ref _msg action = action

log_retrieval ref msg start end = do
	ct <- getCurrentTime
	let str = printf "[%-35s] %s [%8.1fms] %s" (show ct) (connLogSymbol_ $ connection $ ref) (diffms start end) msg
	writeChan (solid_logchan_ $ logstuff_ $ ref) $ do
		hPutStrLn (h_http_log_ $ globalstuff_ $ ref) str

-- TODO: Remove this?
log_time_uri ref msg uri = internal_log_time_msg ref (printf "%s: %s" msg (show uri))

-- TODO: Redo indenting?
log_time_interval ref name action = do
	time_pre <- getCurrentTime
	indents <- readIORef (logindents ref)
	let indent_text = replicate (fromIntegral indents) ':'
	internal_log_time_msg ref (printf "  [%-35s %s>] %s" (show time_pre) indent_text name)
	atomicModifyIORef (logindents ref) (\x -> (x + 1, ()))
	actionresult <- action `catch` (\e -> do
		putStrLn $ "log:" ++ name ++ " exception: " ++ (show (e :: SomeException))
		throwIO e)
	atomicModifyIORef (logindents ref) (\x -> (x - 1, ()))
	time_post <- getCurrentTime
	internal_log_time_msg ref (printf "  [%-35s %s<] %s (%7.1fms)" (show time_post) indent_text name (diffms time_pre time_post))
	return actionresult

log_time_interval_http _ref name action = action `catch` (\e -> do
	putStrLn $ "log_http:" ++ name ++ " exception: " ++ (show (e :: SomeException))
	throwIO e)

log_page_result ref status_before log_time state_before uri params effuri pagetext status_after state_after = do
	doLOGGING_DEBUG $ "log_page_result start: " ++ show log_time ++ " | " ++ show effuri
	(charname, charasc) <- do
		let getSessState var = do
			unless (stateValid_ ref) $ do
				putStrLn $ "State invalid while logging and trying to get session state"
			Just (_, st) <- readIORef $ state ref
			let value = case st of
				(_requestmap, sessionmap, _charmap, _ascmap, _daymap) -> Data.Map.lookup var sessionmap
			return (value :: Maybe String)
		Just charname <- getSessState "character"
		Just charasc <- getSessState "ascension number"
		return (charname, charasc)
	let Just sessid = get_sessid ref
	print_log_msg ref (charname ++ "-" ++ charasc ++ "-detailed.txt") $ LogItem { time = log_time, apiStatusBefore = status_before, apiStatusAfter = status_after, stateBefore = state_before, stateAfter = state_after, sessionId = sessid, requestedUri = uri, parameters = params, retrievedUri = effuri, pageText = pagetext }
	doLOGGING_DEBUG $ "log_page_result done: " ++ show log_time ++ " | " ++ show effuri

log_chat_messages ref text = (do
	let integerFromObj name jsobj = case valFromObj name jsobj of
		Ok (JSString s) -> case read_as $ fromJSString s of
			Just i -> Ok (i :: Integer)
			_ -> Error "string does not represent a number"
		Ok (JSRational _ r) -> Ok (round r :: Integer)
		_ -> Error "unknown number type"

	let handle_msg m = (do
		let rawjson = encodeStrict m
--		putStrLn $ "DEBUG log_chat: " ++ rawjson
		let mtype = valFromObj "type" m
		let mmsg = valFromObj "msg" m :: Result String
		let mtime = integerFromObj "time" m
		let mmid = integerFromObj "mid" m
		let mchannel = valFromObj "channel" m :: Result String
		let mwhoid = case valFromObj "who" m of
			Ok jswho -> integerFromObj "id" jswho
			_ -> Error "no who value"
		let mforid = case valFromObj "who" m of
			Ok jswho -> integerFromObj "id" jswho
			_ -> Error "no who value"
		let mplayerid = case mforid of
			Ok id -> Ok id
			_ -> mwhoid
		case (mtype, mtime, mmsg, mplayerid, mmid, mchannel) of
			(Ok "public", Ok time, Ok msg, Ok playerid, Ok mid, Ok channel) -> do
--				putStrLn $ "DEBUG chat public: " ++ show (time, playerid, channel, mid)
				doChatLogAction ref $ \db -> do
					do_db_query_ db "INSERT OR IGNORE INTO public(mid, time, channel, playerid, msg, rawjson) VALUES(?, ?, ?, ?, ?, ?);"
						[Just $ Data.ByteString.Char8.pack $ show $ mid, Just $ Data.ByteString.Char8.pack $ show $ time, Just $ Data.ByteString.Char8.pack $ channel, Just $ Data.ByteString.Char8.pack $ show $ playerid, Just $ Data.ByteString.Char8.pack $ msg, Just $ Data.ByteString.Char8.pack $ rawjson]
			(Ok "private", Ok time, Ok msg, Ok playerid, _, _) -> do
--				putStrLn $ "DEBUG chat private: " ++ show (time, playerid)
				doChatLogAction ref $ \db -> do
					do_db_query_ db "INSERT INTO private(time, playerid, msg, rawjson) VALUES(?, ?, ?, ?);"
						[Just $ Data.ByteString.Char8.pack $ show $ time, Just $ Data.ByteString.Char8.pack $ show $ playerid, Just $ Data.ByteString.Char8.pack $ msg, Just $ Data.ByteString.Char8.pack $ rawjson]
			(Ok _, Ok time, Ok msg, _, _, _) -> do
--				putStrLn $ "DEBUG chat other: " ++ show (time, oktype)
				doChatLogAction ref $ \db -> do
					do_db_query_ db "INSERT INTO other(time, msg, rawjson) VALUES(?, ?, ?);"
						[Just $ Data.ByteString.Char8.pack $ show $ time, Just $ Data.ByteString.Char8.pack $ msg, Just $ Data.ByteString.Char8.pack $ rawjson]
			_ -> do
				putStrLn $ "WARNING: unrecognized chat type"
				doChatLogAction ref $ \db -> do
					do_db_query_ db "INSERT INTO unrecognized(rawjson) VALUES(?);"
						[Just $ Data.ByteString.Char8.pack $ rawjson]
		return ()) `catch` (\e -> do
			putStrLn $ "ERROR: handle_msg exception: " ++ show (e :: SomeException)
			return ())

	let Ok json = decodeStrict $ text
	let Ok (JSArray msglist) = valFromObj "msgs" json
	mapM_ (\x -> case x of
		JSObject m -> handle_msg m
		_ -> putStrLn $ "WARNING: unrecognized chat message") msglist
	return ()) `catch` (\e -> do
		return (e :: SomeException)
		doChatLogAction ref $ \db -> do
			do_db_query_ db "INSERT INTO oldchat(text) VALUES(?);"
				[Just $ Data.ByteString.Char8.pack $ text]
--		putStrLn $ "DEBUG: log_chat_messages exception: " ++ show (e :: SomeException)
		return ())
