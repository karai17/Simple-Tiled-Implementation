# Change Log

## 2016-01-12: v0.14.1.12

* Added: Basic support for object layers in Bump plugin (thanks @premek)
* Changed: New line token from CRLF to LF
* Fixed: Sprite batches should now respect the map draw order

## 2016-01-01: v0.14.1.11

* Fixed: Various bugs in the Box2D plugin (thanks @ChrisWeisiger)
* Fixed: Various bugs in the Bump plugin (thanks @bobbyjoness)

## 2015-12-31: v0.14.1.10

* Fixed: Box2D plugin was not recognizing a tile's embedded object group

## 2015-11-19: v0.14.1.9

* Changed: key in image cache to formatted path of image

## 2015-11-16: v0.14.1.8

* Added: image cache to STI module [sponsored by Binary Cocoa]
* Added: STI:flush() to clear out image cache

## 2015-11-15: v0.14.1.7

* Added: support for offsetting maps [sponsored by Binary Cocoa]
* Changed: Map.setDrawRange is more optimized via recycling tables
* Changed: render order now defaults to "right-down"

## 2015-11-07: v0.14.1.6

* Fixed: tileset images not being properly filtered
* Fixed: bump.lua plugin missing world argument in draw

## 2015-10-14: v0.14.1.5

* Added: bump.lua plugin (thanks @bobbyjoness)

## 2015-10-12: v0.14.1.4

* Fixed: removing a layer now properly removes tile and object instances
* Fixed: box2d plugin now properly removes collision objects

## 2015-10-09: v0.14.1.3

* Fixed: flipping animated tiles properly display
* Fixed: rotating animated tiles properly display
* Fixed: rotating tile objects properly display
* Fixed: box2d plugin properly creates rotated and flipped tile objects
* Fixed: box2d plugin no longer crashes when drawing a line with two vertices

## 2015-10-07: v0.14.1.2

* Added: support for all render orders (rd, ru, ld, lu)
* Added: support for sensors in the box2d plugin (only works on individual tiles and objects; sensor = true)
* Changed: addCustomLayer's index argument is now optional and defaults to the end of the array
* Fixed: a crash when using Base64 (uncompressed) with LOVE 0.9.2

## 2015-10-03: v0.14.1.1

* Added: support for gzip compressed maps (requires LOVE 0.10.0+)

## 2015-09-30: v0.14.1.0

* Added: support for Base64 compressed maps (requires LuaJIT)
* Added: support for zlib compressed maps (requires LOVE 0.10.0+)

## 2015-09-28: v0.14.0.1

* Added: Support for all staggered types (x/y, even/odd, iso/hex)

## 2015-09-27: v0.14.0.0

* Added: Hexagonal map support (thanks EntranceJew!)
* Added: Error message for compressed maps
* Fixed: box2d plugin threw an error in some cases (thanks maxha651!)

## 2015-09-17: v0.13.1.4

* Changed: sanity checks now search for love.physics instead of love.physics.*

## 2015-09-16: v0.13.1.3

* Changed: Improved documentation

## 2015-09-16: v0.13.1.2

* Changed: Simplified plugins
* Changed: Namespaced the box2d plugin
* Removed: Non-LOVE frameworks (they didn't work)

## 2015-09-16: v0.13.1.1

* Added: LDoc documentation
* Added: Plugin system where devs can extend STI
* Added: Reinstated the Box2D integration as a plugin

## 2015-09-15: v0.13.1.0

* Added: Map:convertToCustomLayer() now returns the layer
* Changed: Tightened localization of some functions
* Removed: Box2D collision integration
* Removed: Unused functions

## 2015-07-31: v0.12.3.0

* Added: Tiled version number to Map.tiledversion
* Added: Map.objects table indexed by unique object IDs
* Added: A better error message when trying to use Tile Collections
* Changed: Version number should now match Tiled's version number
* Changed: You must now add ".lua" in the filename of a new map as this is consistent with other libraries
* Changed: Renamed "pure" framework to "lua" (still doesn't work, though!)
* Changed: Map:setDrawRange no longer inverts tx and ty for you, do it yourself!
* Changed: Map:draw no longer accepts scale values, use love.graphics.scale!
* Fixed: A bug where tile objects were drawing an object border
* Removed: Corona framework file

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
* Changed: Added \_LICENSE, \_URL, \_VERSION, and \_DESCRIPTION properties to core STI object

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
