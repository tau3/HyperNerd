{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE OverloadedStrings #-}
module Entity where

import           Control.Monad.Catch
import qualified Data.Map as M
import qualified Data.Text as T
import           Data.Time
import           Text.Printf

data EntityException = EntityException T.Text deriving Show

instance Exception EntityException

data Property = PropertyInt Int
              | PropertyText T.Text
              | PropertyUTCTime UTCTime
                deriving (Eq, Show)

type Properties = M.Map T.Text Property

data Entity = Entity { entityId :: Int
                     , entityName :: T.Text
                     , entityProperties :: M.Map T.Text Property
                     } deriving (Eq, Show)


extractProperty :: (IsProperty a, MonadThrow m) => T.Text -> Entity -> m a
extractProperty fieldName entity =
    do property <- maybe (throwM $ EntityException (T.pack $ printf "No field '%s' for entity '%s'" fieldName (entityName entity)))
                   return
                   (M.lookup fieldName $ entityProperties entity)
       value <- either (throwM . EntityException . T.pack . printf "Cannot parse field '%s' of entity '%s': %s" fieldName (entityName entity))
                       return
                       (fromProperty property)
       return value

class IsEntity e where
    toProperties :: e -> Properties
    fromEntity :: MonadThrow m => Entity -> m e

class IsProperty a where
    fromProperty :: Property -> Either T.Text a

instance IsProperty Int where
    fromProperty (PropertyInt x) = Right x
    fromProperty _ = Left "Expected type Int"

instance IsProperty T.Text where
    fromProperty (PropertyText x) = Right x
    fromProperty _ = Left "Expected type Text"

instance IsProperty UTCTime where
    fromProperty (PropertyUTCTime x) = Right x
    fromProperty _ = Left "Expected type UTCTime"

propertyTypeName :: Property -> String
propertyTypeName (PropertyInt _) = "PropertyInt"
propertyTypeName (PropertyText _) = "PropertyText"
propertyTypeName (PropertyUTCTime _) = "PropertyUTCTime"

propertyAsInt :: Property -> Maybe Int
propertyAsInt (PropertyInt x) = Just x
propertyAsInt _ = Nothing

propertyAsText :: Property -> Maybe T.Text
propertyAsText (PropertyText x) = Just x
propertyAsText _ = Nothing

propertyAsUTCTime :: Property -> Maybe UTCTime
propertyAsUTCTime (PropertyUTCTime x) = Just x
propertyAsUTCTime _ = Nothing

restoreProperty :: (T.Text, T.Text, Maybe Int, Maybe T.Text, Maybe UTCTime) -> Maybe (T.Text, Property)
restoreProperty (name, "PropertyInt", Just x,      _, _) = Just (name, PropertyInt x)
restoreProperty (name, "PropertyText",     _, Just x, _) = Just (name, PropertyText x)
restoreProperty (name, "PropertyUTCTime",  _,      _, Just x) = Just (name, PropertyUTCTime x)
-- TODO: don't crash the program if it's impossible to restore a property
restoreProperty _ = error "Khooy"

restoreEntity :: T.Text -> Int -> [(T.Text, T.Text, Maybe Int, Maybe T.Text, Maybe UTCTime)] -> Maybe Entity
restoreEntity name ident rawProperties =
    do properties <- mapM restoreProperty rawProperties
       if null properties
       then Nothing
       else Just Entity { entityName = name
                        , entityId = ident
                        , entityProperties = M.fromList properties
                        }
