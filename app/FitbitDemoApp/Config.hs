{-# LANGUAGE DataKinds #-}
{-# LANGUAGE QuasiQuotes #-}

module FitbitDemoApp.Config
    ( Foo
    , PromptForAppConfig
    , getAppConfig
    , getTokenConfig
    , getTokenConfigPath
    ) where

import           FitbitDemoLib
import           System.Directory (createDirectoryIfMissing, doesFileExist, getHomeDirectory)
import           System.FilePath ((</>), takeDirectory)
import           Text.URI (URI)
import           Text.URI.QQ (uri)

type PromptForAppConfig = IO AppConfig
type Foo = OAuth2App -> AuthCode -> FitbitAPI -> IO TokenConfig

configDir :: FilePath
configDir = ".fitbit-demo"

getAppConfigPath :: IO FilePath
getAppConfigPath = do
    homeDir <- getHomeDirectory
    return $ homeDir </> configDir </> "config.yaml"

getTokenConfigPath :: IO FilePath
getTokenConfigPath = do
    homeDir <- getHomeDirectory
    return $ homeDir </> configDir </> "token.yaml"

newAppConfig :: PromptForAppConfig -> FilePath -> IO AppConfig
newAppConfig prompt p = do
    config <- prompt
    createDirectoryIfMissing True (takeDirectory p)
    encodeYAMLFile p config
    return config

getAppConfig :: PromptForAppConfig -> IO (Maybe AppConfig)
getAppConfig prompt = do
    appConfigPath <- getAppConfigPath
    appConfigExists <- doesFileExist appConfigPath
    if appConfigExists
        then decodeYAMLFile appConfigPath
        else Just <$> newAppConfig prompt appConfigPath

readTokenConfig :: OAuth2App -> Foo -> PromptForCallbackURI -> AppConfig -> IO TokenConfig
readTokenConfig oauth2 f prompt (AppConfig fitbitAPI@(FitbitAPI clientId _)) = do
    authCode <- getAuthCode oauth2 clientId prompt
    tokenConfig <- f oauth2 authCode fitbitAPI
    tokenConfigPath <- getTokenConfigPath
    encodeYAMLFile tokenConfigPath tokenConfig
    return tokenConfig

getTokenConfig :: OAuth2App -> Foo -> PromptForCallbackURI -> AppConfig -> IO TokenConfig
getTokenConfig oauth2 f prompt config = do
    tokenConfigPath <- getTokenConfigPath
    tokenConfigExists <- doesFileExist tokenConfigPath
    if tokenConfigExists
        then do
            Just tokenConfig <- decodeYAMLFile tokenConfigPath
            return tokenConfig
        else readTokenConfig oauth2 f prompt config
