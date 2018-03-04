{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import           Control.Monad (forM_)
import           Control.Monad.IO.Class (liftIO)
import           Data.Monoid ((<>))
import qualified Data.Text.IO as Text (getLine, putStrLn)
import           Data.Time.Clock (UTCTime(..), getCurrentTime)
import           FitbitDemoApp
import           FitbitDemoLib
import qualified Network.HTTP.Req.OAuth2 as OAuth2
                    ( ClientId(..)
                    , ClientPair(..)
                    , ClientSecret(..)
                    , PromptForCallbackUri
                    , evalOAuth2
                    )
import           System.IO (hFlush, stdout)
import qualified Text.URI as URI (mkURI, render)

configDir :: FilePath
configDir = ".fitbit-demo"

promptForAppConfig :: AppConfigPrompt
promptForAppConfig = do
    putStrLn "No Fitbit API configuration was found."
    putStr "Enter Fitbit client ID: "
    hFlush stdout
    clientId <- OAuth2.ClientId <$> Text.getLine
    putStr "Enter Fitbit client secret: "
    hFlush stdout
    clientSecret <- OAuth2.ClientSecret <$> Text.getLine
    return $ AppConfig (OAuth2.ClientPair clientId clientSecret)

promptForCallbackUri :: OAuth2.PromptForCallbackUri
promptForCallbackUri authUri' = do
    putStrLn "Open following link in browser:"
    Text.putStrLn $ URI.render authUri'
    putStr "Enter callback URI including authorization code: "
    hFlush stdout
    URI.mkURI =<< Text.getLine

main :: IO ()
main = do
    AppConfig clientPair <- exitOnFailure $ getAppConfig configDir promptForAppConfig

    let app = mkApp
                (writeTokenConfig configDir . TokenConfig)
                clientPair

    TokenConfig tp <- exitOnFailure $ getTokenConfig configDir app promptForCallbackUri

    t <- getCurrentTime

    (weightGoal, weightTimeSeries) <- OAuth2.evalOAuth2 tp $ (,)
        <$> getWeightGoal app fitbitApiUrl
        <*> getWeightTimeSeries app fitbitApiUrl (Ending (utctDay t) Max)

    Text.putStrLn $ "Goal type: " <> goalType weightGoal
    putStrLn $ "Goal weight: " ++ formatDouble (goalWeight weightGoal) ++ " lbs"
    putStrLn $ "Start weight: " ++ formatDouble (startWeight weightGoal) ++ " lbs"
    forM_ (take 5 weightTimeSeries) $ \(WeightSample day value) ->
        liftIO $ putStrLn $ show day ++ ": " ++ formatDouble value ++ " lbs"
