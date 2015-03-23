# Change Log

## 2015-03-22: v0.9.8

* Fixed: A bug where Tiles without a Properties list would crash


## 2015-02-02: v0.9.7

* Added: userdata to Box2D fixtures
* Changed: changelog.txt -> CHANGELOG.md
* Changed: Flipping tiles now happens in both tile layers and object layers
* Fixed: A bug where tile objects were drawing oddly in some cases
* Fixed: A bug where circles would error if physics was disabled


## 2015-01-28: v0.9.6

* Added: getLayerProperties(), getTileProperties(), and getObjectProperties()
* Fixed: A bug where flipped tiles crashed STI during initCollision()
* Fixed: Flipped collision tiles now have correct offset
* Removed: Reverted the change in v0.9.3 that filled in empty tiles with false


## 2014-12-15: v0.9.5

* Fixed: A bug where tile collision objects were using the wrong size in some cases
* Fixed: A bug where flipped tiles weren't always creating collision objects


## 2014-12-05: v0.9.4

* Changed: STI's canvas plays nicely with other libraries
* Changed: addCustomLayer() now returns a handle on the created layer


## 2014-12-03: v0.9.3

* Added: Local Tile IDs to Tile objects
* Added: Terrain information
* Fixed: Some conversion functions
* Changed: Tile Layers now contain "false" instead of "nil" where there is no tile
* Changed: Added _LICENSE, _URL, _VERSION, and _DESCRIPTION properties to core STI object


## 2014-09-29: v0.9.2

* Added: Support for drawing tiles in object layers
* Fixed: Incorrect calculation of some collision objects


## 2014-09-26: v0.9.1

* Fixed: A crash when a collidable tile is initialized but not used
* Removed: Public access to formatPath(), rotateVertex(), and convertEllipseToPolygon()


## 2014-09-24: v0.9.0

* Added: Animated tiles! (Thanks to Clean3d)
* Fixed: A crash when a collidable rectangle has no rotation value
* Fixed: Incorrect values given to orthogonal collision objects


## 2014-09-24: v0.8.3

* Added: Map:convertScreenToTile() and Map:convertTileToScreen()
* Added: Map:convertScreenToIsometricTile() and Map:convertIsometricTileToScreen()
* Added: Map:convertScreenToStaggeredTile() and Map:convertStaggeredTileToScreen()
* Fixed: Map:removeLayer() now works properly
* Changed: Tile Objects now use the tile's collision map by default


## 2014-09-22: v0.8.2

* Added: "collidable" property for objects, tiles, and layers
	* if collidable is set to true in Tiled, STI will pick it up and set all appropriate entities to collidable objects
* Fixed: Physics module no long required if not needed.
* Fixed: Whitespace discrepencies
* Changed: Map:initWorldCollision() now supports a whole lot more


## 2014-09-21: v0.8.1

* Added: README now lists minimum requirements
* Changed: README updated with new collision system
* Changed: Map:enableCollision() renamed to Map:initWorldCollision()
* Changed: Map:drawCollisionMap() renamed to Map:drawWorldCollision()
* Changed: Updated framework files (still no real Lua/Corona support)
* Changed: Tidied up collision code
* Removed: Map:getCollisionMap()


## 2014-09-20: v0.8.0

* Added: Box2D collision via Map:enableCollision()
* Added: Map:convertEllipseToPolygon()


## 2014-09-17: v0.7.6

* Added: Map:convertScreenToIsometric and Map:convertIsometricToScreen
* Added: Map:setObjectCoordinates
* Added: Map:rotateVertex
* Fixed: Adjusted map positioning for Isometric and Staggered maps
* Fixed: Object positioning in Isometric maps
* Removed: Temporary fix for Tiled 0.9.1


## 2014-08-05: v0.7.5

* Fixed: Properties offset by 1
* Fixed: Drawing a single Layer can now use Layer's name/index


## 2014-04-28: v0.7.4

* Fixed: Canvas resize type


## 2014-04-18: v0.7.3

* Fixed: Canvas using wrong filter


## 2014-04-08: v0.7.2

* Removed: Dependency for LuaJIT's bitwise operations


## 2014-04-08: v0.7.1

* Added: Map:resize(w, h)
* Changed: Map:draw() now takes two optional arguments: ScaleX and ScaleY
* Changed: STI now draws to a Canvas before drawing to screen (fixes scaling oddities)


## 2014-04-07: v0.7.0

* Added: Files for Corona and Pure Lua implementation
* Changed: Restructured sti.lua into several files
* Changed: Library is now LOVE agnostic and should allow for implementation of other frameworks


## 2014-03-1 : v0.6.16

* Changed: Ellipses now use polygons instead of... Not polygons.


## 2014-03-1 : v0.6.15

* Fixed: Tile spacing calculated properly in all cases


## 2014-02-0 : v0.6.14

* Fixed: Tile properties ACTUALLY being added now!


## 2014-01-2 : v0.6.13

* Added: Missing Tile Flag


## 2014-01-2 : v0.6.12

* Added: drawCollisionMap() now supports Isometric and Staggered maps
* Changed: drawCollisionMap() now requires a collision map parameter
* Changed: setCollisionMap() renamed to getCollisionMap()
* Changed: getCollisionMap() now returns the collision map
* Fixed: Tile properties not being added
* Removed: Map.collision table removed


## 2014-01-2 : v0.6.11

* Added: Descriptive error messages
* Fixed: Image filters for scaling


## 2014-01-2 : v0.6.10

* Fixed: Optimized load time


## 2014-01-25: v0.6.9

* Fixed: Parallax Scrolling


## 2014-01-25: v0.6.8

* Changed: Revised and restructured code
* Changed: createCollisionMap() renamed to setCollisionMap()
* Changed: newCustomLayer() renamed to addCustomLayer()


## 2014-01-24: v0.6.7

* Fixed: Number of tiles wasn't calculated properly


## 2014-01-24: v0.6.6

* Fixed: Spacing wasn't calculated properly


## 2014-01-24: v0.6.5

* Added: Staggered Maps


## 2014-01-24: v0.6.4

* Added: Isometric Maps


## 2014-01-20: v0.6.3

* Added: Tile Flags (flip/rotation)


## 2014-01-20: v0.6.2

* Fixed: A scaling bug


## 2014-01-19: v0.6.1

* Fixed: A bug causing the Collision Map to be nil


## 2014-01-19: v0.6.0

* Added: Sprite Batches


## 2014-01-19: v0.5.0

* Added: Draw Range optimization


## 2014-01-18: v0.4.3

* Added: Layer draw offsets


## 2014-01-17: v0.4.2

* Changed: Organized library a little better


## 2014-01-17: v0.4.1

* Fixed: Tiles incorrectly offset
* Fixed: Drawing concave polygons


## 2014-01-17: v0.4.0

* Added: Draw Object Layers


## 2014-01-16: v0.3.3

* Added: Create new Custom Layer
* Added: Callbacks for all layers
* Added: Remove Layer
* Changed: Simplified sti.new()


## 2014-01-16: v0.3.2

* Fixed: Crash if using Tiled 0.9.1
* Changed: Map structure to remove "map" table


## 2014-01-16: v0.3.1

* Added: Update callback to Custom Layers


## 2014-01-16: v0.3.0

* Added: Support for converting layers to Custom Layers
* Changed: sti.new() no longer requires the file extension


## 2014-01-15: v0.2.2

* Added: Support for basic collision layer


## 2014-01-15: v0.2.1

* Added: Support for map instances
* Added: Name alias to layer indices
* Changed: Sandboxed map environment
* Changed: Data structures are more efficient
* Removed: Unnecessary update function

Thanks to JarrettBillingsley for many of these changes


## 2014-01-14: v0.2.0

* Fixed: Drawing Tile Offset
* Changed: Tile Layer data structure is more efficient
* Changed: Simplified Quad generation


## 2014-01-14: v0.1.0

* Initial Commit
* Added: Orthogonal Map support
* Added: Draw Tile Layers
* Added: Draw Image Layers
* Added: Ignore Hidden Layers
* Added: Layer Opacity
