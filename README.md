
# GLSL Normal/Specular Lighting in Defold
I wanted to make a walk-through of how this could be used. This is a project that experiments using lights and normal/specular maps to make shading. This project is 2d but this concept could be generalized into 3d.

This is the example provided in the above project:
https://mchlkpng.github.io/shader-test/

## 1. Light objects
All the lights are represented through objects. In the `main.collection`, childed under the `/lights` object are objects labelled `/light[number]`, each with a sprite `#sprite`. These objects will be representing the lights and the sprites carry the properties of the lights.
![Light objects in collection](https://i.ibb.co/J5Svwf7/lights.png)
## 2. Light material
All of the sprites of the lights are put under a new material, `light.material`. The purpose of this new material is to exclude the sprites from rendering (they shouldn't appear in the game) and to allow the sprites to store variables that are important to the lighting process.
![light.material](https://i.ibb.co/nzgKG7p/light-material.png)

**NOTE!** It's important that the tag is `light` because no predicate will be created in the render script for it. These sprites will not be rendered.
### light.vp
There's no difference between this and sprite.vp.
### light.fp
The fragment program needs to use the Fragment Constants in order to recognize them.
 ```glsl
 varying mediump vec2 var_texcoord0;

uniform lowp sampler2D texture_sampler;
uniform lowp vec4 tint;

uniform lowp vec4 light_type;
uniform lowp vec4 attenuation;
uniform lowp vec4 pointing_to;
uniform lowp vec4 spot_data;

void main()
{
    // Pre-multiply alpha since all runtime textures already are
    lowp vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);
    //Use the variables so they are actually recognized and changeable.
    lowp vec4 useless = light_type * attenuation * pointing_to * spot_data;
    gl_FragColor = texture2D(texture_sampler, var_texcoord0.xy) * tint_pm * useless/useless;
//Add `*useless/useless` so the variables are recognized by the program in platforms that can only support OpenGL ES 2.0
}
```

It's easier to store all of these variables as properties of the lights' sprites.

## 3. Light Fragment Constants
These fragment constants store important variables for calculating lighting and are used by the `lighting.lua` module that facilitates light creation.

### tint
Stores the color of the light.

### light_type
This stores a value (0, 1, 2) that represents whether this light is a directional, point, or spotlight light caster. Check out [this LearnOpenGL](https://learnopengl.com/Lighting/Light-casters) that explains what they are.

### attenuation
This variable stores values that help calculate [Attenuation](https://learnopengl.com/Lighting/Light-casters#:~:text=To%20reduce%20the%20intensity%20of%20light). These values are used in an equation that reduces the intensity of light over a distance.

 - attenuation.x - constant
 - attenuation.y - linear
 - attenuation.z - quadratic
 - attenuation.w - 0 (unused)
 
 ### pointing_to
 This value stores the position of where the light is pointing to. This is only used by point lights and directional lights. Even though position is vector3, this must be stored as a vector4 (the .w doesn't matter.)
 
 ### spot_data
 This variable holds different information regarding spotlights in its x and y values.
 
 - spot_data.x - phi (the inner cutoff of a spotlight)
 - spot_data.y - gamma (the outer cutoff of a spotlight)
 - spot_data.z/w - 0 (unused)

## 4. Passing the light to the render script
The `lighting.lua` module was made to facilitate passing values to the render script.

### lighting.add_light(url, light_type, data_table)
This function adds a light to the rendering.

 - **url**
	 - The url of the object representing the light
 - **light_type**
	 - Constant that tells whether this will be a directional, point, or spotlight. Should except the set constants `lighting.LIGHT_TYPE_DIRECTIONAL()`, `lighting.LIGHT_TYPE_POINT()`, or `lighting.LIGHT_TYPE_SPOTLIGHT()`.
- **data_table**
	- This is the table containing the necessary values for creating a light.
	
		- **color** (vector3) - Color of the light
		
		#### For Directional and Spotlight Lights:
		- **pointing_to** (vector3) - The position the light will be pointing to that will determine direction. This is calculate from their position. (position - pointing_to)
	  
	  #### For Point and Spotlight lights:
	  - **constant** (number) - Constant value for attenuation equation.
	  - **linear** (number) - Linear value for attenuation equation.
	  - **quad** (number) - Quadratic value for attenuation equation.
	  
	  #### For Spotlights only:
	  - **phi** (number) - Inner cutoff angle (in radians)
	  - **gamma** (number) - Outer cuoff angle (in radians)

### Example:
```lua
function init(self)
local r = 1024
	lighting.add_light("/light", lighting.LIGHT_TYPE_DIRECTIONAL(), {color = vmath.vector4(1, 1, 1, 0.5), pointing_to = vmath.vector3(0, 0, 0)})
	
	lighting.add_light("/light1", lighting.LIGHT_TYPE_SPOTLIGHT(), {
		constant = 1,
		linear = 1/r,
		quad = 1/(r*r),
		pointing_to = go.get_position("/go"),
		phi = math.r(30),
		gamma = math.r(45)
		})
		
	lighting.add_light("/light2", lighting.LIGHT_TYPE_POINT(), {
	constant = 1/5,
	linear = 1/r,
	quad = 1/(r*r)
	})
end
```
This module also comes with a few other functions:

### lighting.remove_light(url)
Remove a light
### lighting.update_value(url, key, value, forAnim)
Update a light's value of `key`, which will be `position`, `light_type`,  `color`, `constant`, `linear`, `quad`, `pointing_to`, `phi`, or `gamma`.
The parameter `forAnim` is for internal use and should be set to false or removed.
### lighting.animate_value(url, key, playback, value, easing, duration, delay, callback)
Animates one of the above values (except `light_type`, try it, I dare you). Works like and uses the `go.animate` function; `key` replaces `property` and `value` replaces `to`.

### lighting.cancel_animations(url, optionalkey)
Cancels animations. If no `optionalkey`, it cancels all animations on the light. Put in optional key (which will be one of the 8 above) to cancel one specific animation.

### lighting.update_view_position(position)
Send the render script the world view position. This helps determine reflection. Should be called each time camera is moved or every frame.

## Add code to one script's update() function:
Render scripts cannot access go properties, so for the animations to actually work, this code needs to be added to one script's `update(self, dt)` function, (a script that has required the module):
```lua
function update(self, dt)
	lighting.update_view_position(go.get_position("/camera"))

	for k, v in pairs(lighting.to_update) do
		if v.key == "color" then
			lighting.update_value(v.url, v.key, go.get(v.url.."#sprite", "tint"), true)
		elseif v.key == "constant" then
			lighting.update_value(v.url, v.key, go.get(v.url.."#sprite", "attenuation.x"), true)
		elseif v.key == "linear" then
			lighting.update_value(v.url, v.key, go.get(v.url.."#sprite", "attenuation.y"), true)
		elseif v.key == "quad" then
			lighting.update_value(v.url, v.key, go.get(v.url.."#sprite", "attenuation.z"), true)

		elseif v.key == "phi" then
			lighting.update_value(v.url, v.key, go.get(v.url.."#sprite", "spot_data.x"), true)
		elseif v.key == "gamma" then
			lighting.update_value(v.url, v.key, go.get(v.url.."#sprite", "spot_data.y"), true)
		elseif v.key == "position" then
			lighting.update_value(v.url, v.key, go.get(v.url, "position"), true)
		elseif v.key == "pointing_to" then
			local pt = go.get(v.url.."#sprite", "pointing_to")
			lighting.update_value(v.url, "pointing_to", vmath.vector3(pt.x, pt.y, pt.z), true)
		end
	end
end
``` 
## 5. The Render script
Minimal additions were added to the render script. This will be based off the render script of Defold 1.8.1, but the additions are minimal and can be added to any new renditions of the render script. 

### a. Set constants
Several tables and variables will need to be created to pass the constants to the sprites' fragment program.
In the render script's `init(self)`:
```lua
    self.spec_strength = 1 --general specular strength
    self.view_pos = vmath.vector3() -- world view position

    self.light_positions = {} --table carrying lights and all of their values
    --(it's called light_positons because it used to only carry info about position)
```
Add this function:
```lua
function light_pos_array(self)
    self.light_pos_array = {} --Light positons
    self.light_col_array = {} --Light colors
    self.light_atten_array = {} --Light attenuation
    self.light_dir_array = {} --Light direction
    self.light_spot_array = {} --Light phi and gamma
    for k, v in pairs(self.light_positions) do
        table.insert(self.light_pos_array, vmath.vector4(v.position.x, v.position.y, v.position.z, v.light_type))
        table.insert(self.light_col_array, v.color)
        table.insert(self.light_atten_array, vmath.vector4(v.constant, v.linear, v.quad, 0))
        table.insert(self.light_dir_array, vmath.vector4(v.direction.x, v.direction.y, v.direction.z, 0))
        table.insert(self.light_spot_array, vmath.vector4(v.phi, v.gamma, 0, 0))
    end
end
```
Information in tables can only be passed to the fragment program as arrays, so this function takes all  the lights and parses the information into arrays.

Now in the `update()` function, the constants are set.
```lua
--in the update(self, dt) of our.render_script
if self.light_change then
        light_pos_array(self)
        -- This is so we do not update the lights if not needed
        -- self.light_change is set to true for an update
    end



    local constants = render.constant_buffer()
    constants.ambient = self.ambient_color
    constants.num_lights = vmath.vector4(#self.light_pos_array)
    constants.light_positions = self.light_pos_array
    constants.light_colors = self.light_col_array
    constants.light_attens = self.light_atten_array
    constants.light_directions = self.light_dir_array
    constants.light_spotdata = self.light_spot_array
    constants.spec_strength = vmath.vector4(self.spec_strength)
    constants.view_pos = vmath.vector4(self.view_pos.x, self.view_pos.y, self.view_pos.z, 0)
```

### b. Add new messages
To communicate with the script, messages are passed to it to create, remove, and update lights.
```lua
-- in the onmessage(self, message_id, message) function of our.render_script
...
elseif message_id == hash("add_light") then
        self.light_positions[message.name] = {
            position = vmath.vector3(message.position.x, message.position.y, message.position.z),
            light_type = message.light_type,
            color = message.color,
            constant = message.constant,
            linear = message.linear,
            quad = message.quad,
            direction = vmath.vector3(message.direction.x, message.direction.y, message.direction.z),
            phi = message.phi,
            gamma = message.gamma
        }
        light_pos_array(self)
    elseif message_id == hash("remove_light") then
        self.light_positions[message.name] = nil
        light_pos_array(self)
    elseif message_id == hash("view_pos") then
        self.view_pos = message.pos
    elseif message_id == hash("update_light_value") then
        self.light_positions[message.url][message.key] = message.value
        self.light_change = true
    end
    ...
```


### c. Add predicate for the "newsprite" material

The sprites that actually do the calculations work off the `newsprite.material` material that has the tag `newsp`(shown later), so we need to add that predicate to be rendered.

  
```lua
-- in our.render_script
function  init(self)
-- added predicate "newsp"
self.predicates = create_predicates("newsp", "tile", "gui", "particle", "model", "debug_text")

...

-- in update(self, dt)
	-- render the other components: sprites, tilemaps, particles etc
	--
	render.enable_state(render.STATE_BLEND)
	-- inserted right here! Make sure to pass the constants
	render.draw(predicates.newsp, {frustum = camera_world.frustum.frustum, constants = constants})
	-- ^
	render.draw(predicates.tile, camera_world.frustum)
	render.draw(predicates.particle, camera_world.frustum)
	render.disable_state(render.STATE_DEPTH_TEST)

	-- at the end of update()
	self.light_change = false
```
**NOTE** - Remember, this was done with the how the render script looked like in Defold 1.8.1. The script may look different in later updates. This would be a more traditional approach:

```lua
function init(self)
	self.newsppred = render.predicate({"newsp"})
...
-- in update(self, dt)
	render.draw(self.newsppred, {frustum = frustum, constants = constants})
	-- note: for frustum, make sure to use the same frustum as the rest 
	-- of the predicates. If a table is being passed in the 2nd argument
	-- of render.draw, it's a table.
	-- Pass the table's ".frustum".
```
## The "newsprite" Material
The material `newsprite.material` is used for all the sprites that will be preforming the lighting calculations. 
![newsprite.material](https://i.ibb.co/DpQcvpV/newsprite.png)

Sprites using this material must have a diffuse, normal, and specular texture. This is done with [Rename Patterns](https://defold.com/manuals/atlas/#:~:text=_paged_atlas.material.-,Rename%20Patterns,-A%20comma%20%28%C2%B4,%C2%B4%29%20separated).
![enter image description here](https://i.ibb.co/d6km01m/textures.png)
Notice how because all of the lighting calculations are done during runtime, the sprites will not show. In practice, it would be probably be a good idea to have a backup sprite to be able to see in the menu for debug purposes.

### newsprite.vp
Vertex program:
```glsl
uniform highp mat4 view_proj;

// positions are in world space
attribute highp vec4 position;
attribute mediump vec2 texcoord0;

varying mediump vec2 var_texcoord0;
varying highp vec4 var_position;
varying highp mat4 var_viewproj;

void main()
{
    gl_Position = view_proj * vec4(position.xyz, 1.0);
    var_texcoord0 = texcoord0;
    var_position = position;
    var_viewproj = view_proj;
}

```

## The newsprite.fp Fragment Program
The fragment program is a little lengthy and it would not be a good use of time explaining how everything works in here, as it's information I got from the [LearnOpenGL](https://learnopengl.com/Lighting/Colors) tutorial. I recommend taking a look at this to get a better understanding of lighting.
In short, this is the program that does all of the calculation for light reflection. You can check it out [here](https://github.com/mchlkpng/shader-test/blob/main/main/materials/newsprite/newsprite.fp).

By the way, this is the attenuation equation:

	attenuation = 1.0 / ( c + (l * d) + (q * d * d ) )
`c` is the constant, 	`l` is the linear value, 	`q` is the quadratic value, and `d` is the distance.  And if you wondering, yes, it is 1 over a quadratic equation.
