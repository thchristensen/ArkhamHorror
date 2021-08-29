module Arkham.Types.Location.Cards.StudentUnion
  ( StudentUnion(..)
  , studentUnion
  ) where

import Arkham.Prelude

import qualified Arkham.Location.Cards as Cards (studentUnion)
import Arkham.Types.Ability
import Arkham.Types.Classes
import Arkham.Types.Cost
import Arkham.Types.Criteria
import Arkham.Types.GameValue
import Arkham.Types.Location.Attrs
import Arkham.Types.Location.Helpers
import Arkham.Types.Matcher hiding (RevealLocation)
import Arkham.Types.Message
import Arkham.Types.Target

newtype StudentUnion = StudentUnion LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor env)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

studentUnion :: LocationCard StudentUnion
studentUnion =
  location StudentUnion Cards.studentUnion 1 (Static 2) Diamond [Plus, Equals]

instance HasAbilities env StudentUnion where
  getAbilities iid window (StudentUnion attrs) =
    withBaseAbilities iid window attrs $ do
      pure
        [ restrictedAbility attrs 1 Here (ActionAbility Nothing $ ActionCost 2)
        | locationRevealed attrs
        ]

instance LocationRunner env => RunMessage env StudentUnion where
  runMessage msg l@(StudentUnion attrs) = case msg of
    RevealLocation _ lid | lid == locationId attrs -> do
      push $ PlaceLocationMatching (LocationWithTitle "Dormitories")
      StudentUnion <$> runMessage msg attrs
    UseCardAbility iid source _ 1 _ | isSource attrs source -> l <$ pushAll
      [ HealDamage (InvestigatorTarget iid) 1
      , HealHorror (InvestigatorTarget iid) 1
      ]
    _ -> StudentUnion <$> runMessage msg attrs
