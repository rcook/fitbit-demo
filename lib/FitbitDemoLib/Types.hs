module FitbitDemoLib.Types
    ( AccessToken(..)
    , ClientId(..)
    , ClientSecret(..)
    , RefreshToken(..)
    ) where

import           Data.Text (Text)

-- | Fitbit API client ID
newtype ClientId = ClientId Text deriving Show

-- | Fitbit API client secret
newtype ClientSecret = ClientSecret Text deriving Show

-- | Fitbit API access token
newtype AccessToken = AccessToken Text deriving Show

-- | Fitbit API refresh token
newtype RefreshToken = RefreshToken Text deriving Show
