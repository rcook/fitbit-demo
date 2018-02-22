{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Main (main) where

import           Control.Monad (forM_)
import           Data.Monoid ((<>))
import qualified Data.Text.IO as Text (getLine, putStrLn)
import           Data.Time.Clock (UTCTime(..), getCurrentTime)
import           FitbitDemoApp
import           FitbitDemoLib
import           Network.HTTP.Req
                    ( (/:)
                    , Scheme(..)
                    , Url
                    , https
                    )
import qualified Network.HTTP.Req.OAuth2 as OAuth2
                    ( App(..)
                    , ClientId(..)
                    , ClientPair(..)
                    , ClientSecret(..)
                    , PromptForCallbackURI
                    )
import           Text.Printf (printf)
import qualified Text.URI as URI (mkURI, render)
import           Text.URI.QQ (uri)

promptForAppConfig :: PromptForAppConfig
promptForAppConfig = do
    putStrLn "No Fitbit API configuration was found."
    putStr "Enter Fitbit client ID: "
    clientId <- OAuth2.ClientId <$> Text.getLine
    putStr "Enter Fitbit client secret: "
    clientSecret <- OAuth2.ClientSecret <$> Text.getLine
    return $ AppConfig (FitbitAPI (OAuth2.ClientPair clientId clientSecret))

promptForCallbackURI :: OAuth2.PromptForCallbackURI
promptForCallbackURI authUri' = do
    putStrLn "Open following link in browser:"
    Text.putStrLn $ URI.render authUri'
    putStr "Enter callback URI: "
    URI.mkURI =<< Text.getLine

fitbitApp :: OAuth2.App
fitbitApp =
    OAuth2.App
        [uri|https://www.fitbit.com/oauth2/authorize|]  -- authUri
        [uri|https://api.fitbit.com/oauth2/token|]      -- tokenUri

fitbitApiUrl :: Url 'Https
fitbitApiUrl = https "api.fitbit.com" /: "1"

formatDouble :: Double -> String
formatDouble = printf "%.1f"

main :: IO ()
main = do
    Just (AppConfig (FitbitAPI clientPair)) <- getAppConfig promptForAppConfig
    tp0 <- getTokenPair fitbitApp clientPair promptForCallbackURI

    -- TODO: Refactor to use State etc.
    (Right weightGoal, tp1) <- withRefresh fitbitApp fitbitApiUrl clientPair tp0 getWeightGoal
    Text.putStrLn $ "Goal type: " <> goalType weightGoal
    putStrLn $ "Goal weight: " ++ formatDouble (goalWeight weightGoal) ++ " lbs"
    putStrLn $ "Start weight: " ++ formatDouble (startWeight weightGoal) ++ " lbs"

    t <- getCurrentTime
    let range = Ending (utctDay t) Max

    (weightTimeSeries, _) <- withRefresh fitbitApp fitbitApiUrl clientPair tp1  (getWeightTimeSeries range)
    let Right ws = weightTimeSeries
    forM_ (take 5 ws) $ \(WeightSample day value) ->
        putStrLn $ show day ++ ": " ++ formatDouble value ++ " lbs"

    putStrLn "DONE"
