return {
  version = "1.1",
  luaversion = "5.1",
  tiledversion = "0.17.2",
  orientation = "staggered",
  renderorder = "right-down",
  width = 5,
  height = 10,
  tilewidth = 184,
  tileheight = 184,
  nextobjectid = 3,
  staggeraxis = "y",
  staggerindex = "odd",
  properties = {},
  tilesets = {
    {
      name = "iso",
      firstgid = 1,
      tilewidth = 184,
      tileheight = 184,
      spacing = 0,
      margin = 0,
      image = "iso.png",
      imagewidth = 184,
      imageheight = 184,
      tileoffset = {
        x = 0,
        y = 0
      },
      properties = {},
      terrains = {},
      tilecount = 1,
      tiles = {}
    }
  },
  layers = {
    {
      type = "tilelayer",
      name = "Grid",
      x = 0,
      y = 0,
      width = 5,
      height = 10,
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      properties = {},
      encoding = "lua",
      data = {
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1
      }
    },
    {
      type = "objectgroup",
      name = "Objects",
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      draworder = "topdown",
      properties = {
        ["collidable"] = true
      },
      objects = {
        {
          id = 1,
          name = "",
          type = "",
          shape = "rectangle",
          x = 184,
          y = 184,
          width = 184,
          height = 92,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "",
          type = "",
          shape = "rectangle",
          x = 460,
          y = 0,
          width = 130,
          height = 130,
          rotation = 45,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
