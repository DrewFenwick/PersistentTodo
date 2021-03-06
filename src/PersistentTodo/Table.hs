module PersistentTodo.Table
  ( setStatus
  , taskInsert
  , taskSelect
  , deleteTasks
  )
where

import           Opaleye
import           Data.Int
import           Data.Profunctor.Product        ( p2 )


import           PersistentTodo.Task

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

deleteTasks :: (NumberedTaskField -> Field PGBool) -> Delete Int64
deleteTasks pred =
  Delete { dTable = taskTable, dWhere = pred, dReturning = rCount }
