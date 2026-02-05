# ProfileServiceV3
### Theta Version Testing
### NOT Recommended to be used for games in this early development stage

If you're willing to test the system and find bugs/glitches or build it from this point on - go ahead;

There are tons of comments and debug prints, this is still in development.

Found a bug/glitch/error? - DM @coffilhg on Discord with steps to reproduce and console screenshots or a video.

All of the used scripts can be found in [src](src), they are already adjusted to fit the following Hierarchy:

![Hierarchy shows how to organise scripts from this GitHub Repo src; Scripts to put into game.ReplicatedStorage are ClientMain, CoffeeRemotesClient, Counter and GoodSignal_By_Stravant; Insert GetDIIP script into ClientMain, then also insert the CoffeeObjects from src/ReplicatedStorage into the GetDIIP - don't mess this up, GetDIIP can't fnction properly without this modified version of CoffeeObjects. Scripts to put into game.ServerScriptService are ProfileStoreMainV3, Arrangement, CoffeeObjects (from src/ServerScriptService - original latest) and CoffeeRemotesServer; Insert the ProfileStoreV3 into ProfileStoreMainV3; ClientMain is a Script Class Intance with it's RunContext property set to Client, do not confuse this with a LocalScript Class Instance](images/Hierarchy.png "Suggested Hierarchy")

Note that LocalScript by itself doesn't run if parented to **ReplicatedStorage**, you have to insert a **Script** and change it's **RunContext** property to **Client** like shown in the image above.

### To-Do
- [x] Fix ReconcileTable Messing up everything when an entirely new key is added to the PROFILE_TEMPLATE
- [ ] Check if `CoffeeFolder.validateUnlinkedClass(target[k])` removal is possible from ReconcileTable (slight optimization)
- [ ] Make security work
- [ ] Split the ReplicationLookup entries into separate IsPublic, IsSelfPublic, SubscribedPlayers/(true for IsAPublicFolderValue) tables. Arrangement index - value.
- [ ] Use buffers to reduce the cost of Subscribing to a folder; That includes buffering ["c"] (children and their children - all descendants)
- [ ] Make sure under-the-hood CoffeeParser and CoffeeObjects are applied to Mock profiles

## License
ProfileStoreV3 is based off of [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) and uses [GoodSignal](https://github.com/stravant/goodsignal)

Please see [LICENSE](LICENSE)