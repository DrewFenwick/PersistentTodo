{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE LambdaCase #-}

module PersistentTodo.Task
  ( Status(..)
  , Task'(..)
  , Task
  , Title(..)
  , TaskField
  , Place(..)
  , setStatus
  , taskInsert
  , taskSelect
  )
where

import           Opaleye
import           Data.Bool
import           Data.Coerce
import           Data.Int
import           Data.Profunctor
import           Data.Profunctor.Product        ( p2 )
import           Data.Profunctor.Product.TH     ( makeAdaptorAndInstance )
import           Data.Profunctor.Product.Default
                                                ( Default(..) )

newtype Title = Title { getTitle :: String} deriving (Show)

instance Default ToFields Title (Column PGText) where
  def = lmap getTitle def

instance QueryRunnerColumnDefault PGText Title where
  queryRunnerColumnDefault = Title <$> fieldQueryRunnerColumn

data Status
  = Pending
  | Completed
  deriving (Show)

isComplete :: Status -> Bool
isComplete = \case
  Completed -> True
  _         -> False

toStatus :: Bool -> Status
toStatus = bool Pending Completed

instance Default ToFields Status (Column PGBool) where
  def = lmap isComplete def

instance QueryRunnerColumnDefault PGBool Status where
  queryRunnerColumnDefault = toStatus <$> fieldQueryRunnerColumn

data Task' t s = Task
  { title :: t
  , status :: s
  } deriving (Show)

type Task = Task' Title Status
type TaskField = Task' (Field PGText) (Field PGBool)
$(makeAdaptorAndInstance "pTask" ''Task')

type NumberedTask = (Place, Task)
type NumberedTaskField = (Field PGInt4, TaskField)

newtype Place = Place {getPlace :: Int}

instance Default ToFields Place (Column PGInt4) where
  def = lmap getPlace def

instance QueryRunnerColumnDefault PGInt4 Place where
  queryRunnerColumnDefault = Place <$> fieldQueryRunnerColumn

taskTable :: Table (Maybe (Field PGInt4), TaskField) NumberedTaskField
taskTable = table "taskTable" $ p2
  ( tableField "Id"
  , pTask Task { title = tableField "title", status = tableField "condition" }
  )

taskSelect :: Select NumberedTaskField
taskSelect = selectTable taskTable

taskInsert :: Maybe Int -> Task -> Insert Int64
taskInsert key task = Insert { iTable      = taskTable
                             , iRows       = pure $ toFields (key, task)
                             , iReturning  = rCount
                             , iOnConflict = Nothing
                             }

setStatus :: Status -> Int -> Update Int64
setStatus s id = Update
  { uTable      = taskTable
  , uUpdateWith = updateEasy (\(id_, t) -> (id_, t { status = toFields s }))
  , uWhere      = \(id_, _) -> id_ .== toFields id
  , uReturning  = rCount
  }