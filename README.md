# ProfileStoreV3

### Examples & Documentation coming soon...

- update the whole PSV3
```
rojo serve test.project.json
```

- updating packages
```
wally install && rojo sourcemap test.project.json --output sourcemap.json && wally-package-types -s sourcemap.json Packages/ ServerPackages/
```

- update packages only
```
rojo serve sync.project.json
```

```md
--- Structuring GetDIIP and SVCS (CoffeeObjects)---
-- Go strict and optimize 2
--[[--```
!strict
!optimize 2
--]]--```
-- Recommended Sections (Based off an existing extension): (Recommended line to follow)
--- Service & Dependency & RemoteInstance Definitons --- (Line ~3)
--- Type Definitions --- (Line ~50)
--- Wire Unsubscribe, DUV, FCA and FCR --- (Line ~90)
--- [OPTIONAL]			--- Useful for Debug --- (Line ~220)
--- Define Accelerator & Patch CoffeeFolder/it's metatable --- (Line ~240)
--- processChild implementation (to be used in AwaitMethod) --- (Line ~400)
--- Accelerator Class and it's AwaitMethod --- (Line ~500)
```