# Royal Renaissance texture kit

12 seamless textures made with Higgsfield (gpt_image_2_5, 1024x1024) on 2026-10-21 for
`src/shared/MaterialKit.luau`, which applies them across every structure by role.

| File | Used for | Higgsfield job |
| --- | --- | --- |
| royal_ashlar.png | castle and building stone | e23c5480-470d-411e-9971-5ed15ff7fa5c |
| royal_cobbles.png | streets, quays, terrain paths | 5347a499-2292-4768-b898-fe9e560fcb0d |
| royal_slate.png | blue/grey roofs and spires | 1c4eff2e-7da6-47f4-827e-6abf4794fccf |
| royal_terracotta.png | red/orange roofs | 5cfc5982-2e32-4c03-a974-de916e633478 |
| royal_timberframe.png | plastered house walls | 27f385b8-a951-4bb6-ae45-4849c3ccde88 |
| royal_oak.png | doors, decks, planks | 721f3fca-d5c1-4ffb-9c7d-5080e0685ef7 |
| royal_marble.png | temple, gazebos, plinths | 9cc932e6-8067-48a3-9872-fc039c56c8dc |
| royal_stainedglass.png | cathedral windows (decal) | 1135d8ec-c9a4-4bb5-923b-9cee7f9f3462 |
| royal_crimson.png | red banners and flags | 3c1f49e4-cd5b-413b-8d84-1bd3c706aba3 |
| royal_damask.png | blue banners and tapestries | b43d6b7e-41eb-45cd-9645-d7e1f3d0492a |
| royal_frieze.png | cornices, arches, bands | ab6f9511-9758-4f6c-ac3f-ee5eec7d3bc9 |
| royal_flagstone.png | squares, plazas, pavements | d5c50fa8-de43-43c9-b533-b835c1579ea8 |

## Turning them on

1. Download the 12 images from your Higgsfield gallery and save them here with the names above.
2. In Roblox Studio: Window > Asset Manager > Bulk Import, select the 12 files. (Or upload them
   as Decals on the Creator Hub.)
3. Copy each image's asset id (the number) into the matching `asset = ""` in
   `src/shared/MaterialKit.luau`.
4. Rebuild and bake (`rojo build` + `lune run tools/bake-map`), or just press Play: the server
   applies the kit at start.
