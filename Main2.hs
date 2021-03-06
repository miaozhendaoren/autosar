module Main where

import ARSim
import Test.QuickCheck.Random
import System.Random

r1 re op pe     = do Ok x <- rte_read re; Ok y <- rte_call op x; rte_write pe y; return ()

c1              = do re <- requiredDataElement
                     rop <- requiredOperation
                     pe <- providedDataElement
                     runnable Concurrent [ReceiveE re] (r1 re rop pe)
                     return (seal re, seal rop, seal pe)

r2 x            = do return (x*x)

c2              = do pop <- providedOperation
                     serverRunnable Concurrent [pop] r2
                     return (seal pop)

test            = do src <- source [(0.0,5),(0.0,7::Int)]
                     snk <- sink
                     (re,rop,pe) <- component c1
                     pop <- component c2
                     connect rop pop
                     connect src re
                     connect pe snk
           
-- Occasionally gives pattern match failure (in r1)           
main            = do s <- newQCGen; putTraceLabels (fst (simulationRand s test))

