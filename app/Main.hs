{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Main (main) where

import           Control.Exception (catch, throwIO)
import           Control.Monad (forM_)
import           Data.Monoid ((<>))
import qualified Data.Text.IO as Text (getLine, putStrLn)
import           Data.Time.Clock (UTCTime(..), getCurrentTime)
import           FitbitDemoApp
import           FitbitDemoLib
import           Network.HTTP.Types (unauthorized401)
import           Network.HTTP.Req
                    ( (/:)
                    , Scheme(..)
                    , Url
                    , https
                    )
import qualified Network.HTTP.Req.OAuth2 as OAuth2
                    ( AccessTokenRequest(..)
                    , AccessTokenResponse(..)
                    , App(..)
                    , ClientId(..)
                    , ClientSecret(..)
                    , PromptForCallbackURI
                    , RefreshTokenRequest(..)
                    , RefreshTokenResponse(..)
                    , fetchAccessToken
                    , fetchRefreshToken
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
    return $ AppConfig (FitbitAPI clientId clientSecret)

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

foo :: Foo
foo authCode (FitbitAPI clientId clientSecret) = do
    result <- OAuth2.fetchAccessToken fitbitApp (OAuth2.AccessTokenRequest clientId clientSecret authCode)
    let (OAuth2.AccessTokenResponse at rt) = case result of
                                                Left e -> error e
                                                Right x -> x
    return $ TokenConfig at rt

refresh :: OAuth2.ClientId -> OAuth2.ClientSecret -> TokenConfig -> IO TokenConfig
refresh clientId clientSecret (TokenConfig _ refreshToken) = do
    result <- OAuth2.fetchRefreshToken fitbitApp (OAuth2.RefreshTokenRequest clientId clientSecret refreshToken)
    let (OAuth2.RefreshTokenResponse at rt) = case result of
                                                Left e -> error e
                                                Right x -> x
    let newTokenConfig = TokenConfig at rt
    tokenConfigPath <- getTokenConfigPath
    encodeYAMLFile tokenConfigPath newTokenConfig
    return newTokenConfig

withRefresh :: Url 'Https -> AppConfig -> TokenConfig -> APIAction a -> IO (Either String a, TokenConfig)
withRefresh apiUrl (AppConfig (FitbitAPI clientId clientSecret)) tokenConfig action =
    catch (action apiUrl tokenConfig >>= \result -> return (result, tokenConfig)) $
        \e -> if hasResponseStatus e unauthorized401
                then do
                    newTokenConfig <- refresh clientId clientSecret tokenConfig
                    result <- action apiUrl newTokenConfig
                    return (result, newTokenConfig)
                else throwIO e

formatDouble :: Double -> String
formatDouble = printf "%.1f"

main :: IO ()
main = do
    Just appConfig <- getAppConfig promptForAppConfig
    tc0 <- getTokenConfig fitbitApp foo promptForCallbackURI appConfig

    -- TODO: Refactor to use State etc.
    (Right weightGoal, tc1) <- withRefresh fitbitApiUrl appConfig tc0 getWeightGoal
    Text.putStrLn $ "Goal type: " <> goalType weightGoal
    putStrLn $ "Goal weight: " ++ formatDouble (goalWeight weightGoal) ++ " lbs"
    putStrLn $ "Start weight: " ++ formatDouble (startWeight weightGoal) ++ " lbs"

    t <- getCurrentTime
    let range = Ending (utctDay t) Max

    (weightTimeSeries, _) <- withRefresh fitbitApiUrl appConfig tc1  (getWeightTimeSeries range)
    let Right ws = weightTimeSeries
    forM_ (take 5 ws) $ \(WeightSample day value) ->
        putStrLn $ show day ++ ": " ++ formatDouble value ++ " lbs"

    putStrLn "DONE"
