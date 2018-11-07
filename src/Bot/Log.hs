{-# LANGUAGE OverloadedStrings #-}

module Bot.Log where

import Bot.Replies
import Command
import Control.Monad
import qualified Data.Map as M
import Data.Maybe
import qualified Data.Text as T
import Data.Time
import Effect
import Entity
import Events
import Numeric.Natural
import Property

data LogRecord = LogRecord
  { lrUser :: T.Text
  , lrChannel :: T.Text
  , lrMsg :: T.Text
  , lrTimestamp :: UTCTime
  }

timestampPV :: T.Text
timestampPV = "timestamp"

type Seconds = Natural

instance IsEntity LogRecord where
  toProperties lr =
    M.fromList
      [ ("user", PropertyText $ lrUser lr)
      , ("channel", PropertyText $ lrChannel lr)
      , ("msg", PropertyText $ lrMsg lr)
      , (timestampPV, PropertyUTCTime $ lrTimestamp lr)
      ]
  fromProperties properties =
    LogRecord <$> extractProperty "user" properties <*>
    extractProperty "channel" properties <*>
    extractProperty "msg" properties <*>
    extractProperty timestampPV properties

recordUserMsg :: Sender -> T.Text -> Effect ()
recordUserMsg sender msg = do
  timestamp <- now
  _ <-
    createEntity
      "LogRecord"
      LogRecord
        { lrUser = senderName sender
        , lrChannel = senderChannel sender
        , lrMsg = msg
        , lrTimestamp = timestamp
        }
  return ()

getRecentLogs :: Seconds -> Effect [LogRecord]
getRecentLogs offset = do
  currentTime <- now
  let diff = secondsAsBackwardsDiff offset
  let startDate = addUTCTime diff currentTime
  -- TODO(#358): use "PropertyGreater" when it's ready
  -- limiting fetched logs by 100 untill then
  allLogs <- selectEntities "LogRecord" $ Take 100 $ SortBy timestampPV Desc All
  let result =
        filter (\l -> lrTimestamp l > startDate) $ map entityPayload allLogs
  return result

secondsAsBackwardsDiff :: Seconds -> NominalDiffTime
secondsAsBackwardsDiff = negate . fromInteger . toInteger

intToSeconds :: Int -> Seconds
intToSeconds = fromInteger . toInteger . abs

randomLogRecordCommand :: CommandHandler T.Text
randomLogRecordCommand Message { messageSender = sender
                               , messageContent = rawName
                               } = do
  let name = T.toLower $ T.strip rawName
  user <-
    if T.null name
      then return $ senderName sender
      else return name
  entity <-
    listToMaybe <$>
    selectEntities
      "LogRecord"
      (Take 1 $ Shuffle $ Filter (PropertyEquals "user" $ PropertyText user) All)
  maybe
    (return ())
    (fromEntityProperties >=> replyToUser user . lrMsg . entityPayload)
    entity
