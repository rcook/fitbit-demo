module FitbitChart.SSM.Types
    ( ParameterName(..)
    ) where

import           Data.Text (Text)

newtype ParameterName = ParameterName Text deriving Show
