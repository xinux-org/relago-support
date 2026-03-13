module Main (main) where

import Server qualified (run)

main :: IO ()
main = do
  putStrLn "Hello, Haskell!"
  Server.run
