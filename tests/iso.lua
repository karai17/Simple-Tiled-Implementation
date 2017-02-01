return {
  version = "1.1",
  luaversion = "5.1",
  tiledversion = "0.17.2",
  orientation = "isometric",
  renderorder = "right-down",
  width = 6,
  height = 6,
  tilewidth = 184,
  tileheight = 184,
  nextobjectid = 7,
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
      width = 6,
      height = 6,
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      properties = {},
      encoding = "lua",
      data = {
        1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1
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
          y = 368,
          width = 184,
          height = 184,
          rotation = 0,
          visible = true,
          properties = {}
        },
        {
          id = 2,
          name = "",
          type = "",
          shape = "rectangle",
          x = 644,
          y = 277,
          width = 260,
          height = 260,
          rotation = 45,
          visible = true,
          properties = {}
        },
        {
          id = 3,
          name = "",
          type = "",
          shape = "polygon",
          x = 410,
          y = 910,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polygon = {
            { x = -41.9565, y = 10 },
            { x = 141.996, y = 10.0616 },
            { x = -42.0254, y = -173.96 }
          },
          properties = {}
        },
        {
          id = 4,
          name = "",
          type = "",
          shape = "polygon",
          x = 681,
          y = 851,
          width = 0,
          height = 0,
          rotation = 45,
          visible = true,
          polygon = {
            { x = -41.9565, y = 10 },
            { x = 141.996, y = 10.0616 },
            { x = -42.0254, y = -173.96 }
          },
          properties = {}
        },
        {
          id = 5,
          name = "",
          type = "",
          shape = "polyline",
          x = 828,
          y = 828,
          width = 0,
          height = 0,
          rotation = 0,
          visible = true,
          polyline = {
            { x = 0, y = 0 },
            { x = 92.0312, y = -91.9688 },
            { x = 275.969, y = -91.9688 },
            { x = 276, y = 92 }
          },
          properties = {}
        },
        {
          id = 6,
          name = "",
          type = "",
          shape = "polyline",
          x = 790,
          y = 108,
          width = 0,
          height = 0,
          rotation = 45,
          visible = true,
          polyline = {
            { x = 0, y = 0 },
            { x = 92.0312, y = -91.9688 },
            { x = 275.969, y = -91.9688 },
            { x = 276, y = 92 }
          },
          properties = {}
        }
      }
    }
  }
}
