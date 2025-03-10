{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NumericUnderscores #-}
module Cardano.Benchmarking.Script
  ( Script
  , runScript
  , parseScriptFileAeson
  )
where

import           Prelude

import           Control.Concurrent (threadDelay)
import           Control.Monad
import           Control.Monad.IO.Class

import           Ouroboros.Network.NodeToClient (IOManager)

import           Cardano.Benchmarking.Script.Action
import           Cardano.Benchmarking.Script.Aeson (parseScriptFileAeson)
import           Cardano.Benchmarking.Script.Core (setProtocolParameters, traceTxGeneratorVersion)
import           Cardano.Benchmarking.Script.Env
import           Cardano.Benchmarking.Script.NodeConfig (shutDownLogging)
import           Cardano.Benchmarking.Script.Store
import           Cardano.Benchmarking.Script.Types
import           Cardano.Benchmarking.Tracer (initDefaultTracers)

type Script = [Action]

runScript :: Script -> IOManager -> IO (Either Error ())
runScript script iom = runActionM execScript iom >>= \case
  (Right a  , s ,  ()) -> do
    cleanup s shutDownLogging
    threadDelay 10_000_000
    return $ Right a
  (Left err , s  , ()) -> do
    cleanup s (traceError (show err) >> shutDownLogging)
    threadDelay 10_000_000
    return $ Left err
 where
  cleanup s a = void $ runActionMEnv s a iom
  execScript = do
    liftIO initDefaultTracers >>= set BenchTracers
    traceTxGeneratorVersion
    setProtocolParameters QueryLocalNode
    forM_ script action
