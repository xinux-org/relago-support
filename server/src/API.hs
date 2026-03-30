{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API where

import API.Upload
import API.Util
import Config
import Data.Kind (Type)
import Servant
import Servant.API.Generic
import Servant.Server.Generic

type API :: Type -> Type
data API route = MkAPI
  { upload :: route :- "upload" :> NamedRoutes UploadRoutes
  }
  deriving stock (Generic)

data ApiServer route = MkApiServer
  { api :: route :- NamedRoutes API
  }
  deriving (Generic)

apiProxy :: Proxy (ToServantApi API)
apiProxy = Proxy

apiHandlers :: (AppConfig) => API AsServer
apiHandlers =
  MkAPI
    { upload = uploadHandlers
    }

mkServer :: (AppConfig) => ApiServer AsServer
mkServer =
  MkApiServer
    { api = apiHandlers
    }

runApi :: (AppConfig) => Application
runApi =
  serveWithContext
    (Proxy @(ToServantApi ApiServer))
    errorFormatters
    (toServant $ mkServer)
