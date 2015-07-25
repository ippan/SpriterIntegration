# Spriter Gideros Integration

a single file script to load [Spriter](http://www.brashmonkey.com) animations to [Gideros](http://giderosmobile.com)

## Current Features

* load Spriter texture pack
* load Spriter scon file
* play object animation
* play bone animation

## Install

* drop Spriter.lua to your project

## Example

    local texture = Texture.new("data/bat.png")

    local texture_pack = Spriter.TexturePack.new(texture, "data/bat.json")
    spriter_object = Spriter.create("data/bat.scon")

    local sprite = spriter_object:createEntitySprite("bat")
    sprite.texture_pack = texture_pack
 
    sprite:play("idle")
 
    stage:addChild(sprite)

## Notes
images in this repository come form my game call [BaBaBear Boom](https://itunes.apple.com/app/bababear-boom/id702178407)