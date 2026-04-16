{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API where

import API.Keys (KeysRoutes, keysHandlers)
import API.Upload (UploadRoutes, uploadHandlers)
import API.Util (errorFormatters)
import Relago.Prelude
import Servant
import Servant.Server.Generic

type API :: Type -> Type
data API route = MkAPI
  { upload :: route :- "upload" :> NamedRoutes UploadRoutes
  , health :: route :- "health" :> Get '[JSON] Integer
  , keys :: route :- "keys" :> NamedRoutes KeysRoutes
  }
  deriving stock (Generic)

data ApiServer route = MkApiServer
  { api :: route :- NamedRoutes API
  }
  deriving (Generic)

apiProxy :: Proxy (ToServantApi API)
apiProxy = Proxy

apiHandlers :: (AppState) => API AsServer
apiHandlers =
  MkAPI
    { upload = uploadHandlers
    , health = heal
    , keys = keysHandlers
    }

heal :: Handler Integer
heal =
  return 1

mkServer :: (AppState) => ApiServer AsServer
mkServer =
  MkApiServer
    { api = apiHandlers
    }

runApi :: (AppState) => Application
runApi =
  serveWithContext
    (Proxy @(ToServantApi ApiServer))
    errorFormatters
    (toServant $ mkServer)
