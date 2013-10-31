{-# LANGUAGE RankNTypes #-}
module Main where

import ARSim
import System.Random
import Test.QuickCheck
import Test.QuickCheck.Property

import Control.Monad.State.Lazy as S
import Control.Monad.Error

import Data.List(nub, sortBy)
import Data.Function(on)
import Data.Tree

import System.IO.Unsafe
import Data.IORef

main = do
  quickCheck $ noShrinking prop_norace

ticketDispenser :: AR c (PO () Int ())
ticketDispenser = component $
                  do pop <- providedOperation
                     irv <- interRunnableVariable (0 :: Int)
                     let r1 = do Ok v <- rte_irvRead irv
                                 rte_irvWrite irv (v+1)
                                 return v
                     serverRunnableN "Server" Concurrent [pop] (\() -> r1)
                     return (seal pop)

client :: Int -> AR c (RO () Int (), PQ Int ())
client n        = component $
                  do rop <- requiredOperation
                     pqe <- providedQueueElement
                     let -- r2 1 = return ()
                         r2 i  = do Ok v <- rte_call rop ()
                                    rte_send pqe v
                                    r2 (i+1)
                     runnableN ("Client" ++ show n) Concurrent [Init] (r2 0)
                     return (seal2 (rop, pqe))

test            = do t <- ticketDispenser
                     (rop1, pqe1) <- client 1
                     (rop2, pqe2) <- client 2
                     (rop3, pqe3) <- client 3 
                     (rop4, pqe4) <- client 4
                     connect rop1 t
                     connect rop2 t
                     connect rop3 t
                     connect rop4 t
                     return (tag [pqe1, pqe2, pqe3, pqe4])


-- Checks that there are no duplicate tickets being issued.
prop_norace :: Property
prop_norace = traceProp test norace
 
norace :: Sim -> Bool
norace s@(Sim (t,ps)) = let ticks = sendsTo ps t in ticks == nub ticks



prop_norace_ioref :: IORef (Maybe Sim) -> Property
prop_norace_ioref ior = traceProp test $ \s -> if norace s 
     then True
     else unsafePerformIO (writeIORef ior (Just s) >> return False)
 
main' repl = do 
  ior <- newIORef Nothing
  r <- quickCheckWithResult stdArgs {replay = repl } $ noShrinking $ prop_norace_ioref ior
  Just x <- readIORef ior
  return (x,(usedSeed r, usedSize r))
  