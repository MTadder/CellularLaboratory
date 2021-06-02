
require("camera")

function love.load()
	print("Loading...")
	gamestate=0
	print("Fetching screen dimensions...")
	love.window.setMode(0,0,{})
	screen_width = love.graphics.getWidth()
	screen_height = love.graphics.getHeight()
	window_width=math.floor(screen_width/1.2)
	window_height=math.ceil(screen_height/1.2)
	love.window.setMode(window_width,window_height,{resizable=false, vsync=true, fullscreen=false, borderless=false})
	print("Done.")
	cursor={mode=1,brushSize=10}
	world=love.physics.newWorld(0,1000,true)
	love.physics.setMeter(10)

	particles={}
	objects={}
	pNextID=0
	pNextIDT=0
	deletedParticles=0
	particleSize=5
	frictionScale=0.7
	debug=false
	particleColor={0,100,100}
	mutationThreshhold=80
	mutationChance=0
	mutateNext=false
	mutateNextID=0
	mutations=0
	lastMutated=false
	gamestate=1
	print("Done loading.")
end
function spawnGround()
	if objects.ground then return end
	objects.ground={}
	objects.ground.body=love.physics.newBody(world,window_width/2,window_height,"static")
	objects.ground.shape=love.physics.newRectangleShape(0,0,window_width+20,100,0)
	objects.ground.fixture=love.physics.newFixture(objects.ground.body,objects.ground.shape,1)
	print("Spawned a new Ground!")
	pNextID=pNextID+1
end

function newParticle(x,y,w,h) -- Revamp this so that the mutations always have a child, and possibly 2
	if particles[pNextID]==nil and fps > 15 then
		mutationChance=love.math.random(100)
		particles[pNextID]={}
		if mutationChance >= mutationThreshhold then
			particles[pNextID].flag=1
			particles[pNextID].shape=love.physics.newCircleShape(w/2)
			mutateNext=true
			mutateNextID=pNextID
		else
			particles[pNextID].shape=love.physics.newCircleShape(w/2)
			particles[pNextID].flag=0
		end
		particles[pNextID].body=love.physics.newBody(world,x,y,"dynamic")
		particles[pNextID].fixture=love.physics.newFixture(particles[pNextID].body,particles[pNextID].shape,1)
		particles[pNextID].id=pNextID
		particles[pNextID].fixture:setFriction(frictionScale)
		particles[pNextID].h=h
		particles[pNextID].w=w

		if mutateNext==true and pNextID~= mutateNextID and particles[mutateNextID].body:isDestroyed()==false then
			local offsetX=w/2
			local offsetY=love.math.random(5)
			particles[pNextID].body:setY(particles[mutateNextID].body:getY()+offsetY)
			particles[pNextID].body:setX(particles[mutateNextID].body:getX()+offsetX)
			particles[pNextID].mut=mutateNextID
			particles[pNextID].joint = love.physics.newWeldJoint( particles[pNextID].body, particles[mutateNextID].body, 0, 0, true )
			particles[pNextID].type="mutated"
			mutateNextID=0
			mutateNext=false
			mutations=mutations+1
		else
			lastMutated=false
		end
		pNextID=pNextID+2
	end
end

function resetAll()
    cursor.brushSize=10
    debug=false
    for i in pairs(particles) do
		if particles[i].body:isDestroyed()==false then
			particles[i].body:destroy()
			deletedParticles=deletedParticles+1
		end
		if particles[id] then particles[id]=nil end
	end
	for i in pairs(objects) do
		if objects[i].body:isDestroyed()==false then
			objects[i].body:destroy()
			deletedParticles=deletedParticles+1
		end
		if particles[id] then particles[id]=nil end
	end
	camera:setPosition(0,0)
end

function mutationCycle()
	for i in pairs(particles) do
		if particles[i].mut and particles[i].body:isDestroyed()==false then
			if particles[i].joint:isDestroyed()==true  or particles[i].joint==nil or particles[particles[i].mut].body:isDestroyed()==true or particles[i].body:isDestroyed()==true then
				particles[i].flag=3
			end
		end
	end
end

function activeCleanup()
	--Detect and delete offscreen particles.
	for i in pairs(particles) do
		if particles[i].body:isDestroyed()==false and
		(particles[i].body:getY() > window_height+particles[i].w+particles[i].h or particles[i].body:getX() > window_width+particles[i].h+particles[i].w or particles[i].body:getX() < -window_width/window_width-particles[i].h-particles[i].w) then
			particles[i].flag=3
			particles[i].fixture:destroy()
			particles[i].body:destroy()
			deletedParticles=deletedParticles+1
		end
	end
end

function love.wheelmoved(x, y)
	cursor.brushSize=cursor.brushSize+(y*3)
end

function love.touchmoved(id,x,y,dx,dy,p)
	newParticle(x,y,particleSize+cursor.brushSize*2,particleSize+cursor.brushSize)
	spawnGround()
	return x,y
end

function love.update(dt)
	world:update(dt)
	if love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
		mouseX=0
		mouseY=0
		mouseDownL=false
		mouseDownR=false
	else
		mouseX=love.mouse.getX()
		mouseY=love.mouse.getY()
		mouseDownL=love.mouse.isDown(1)
		mouseDownR=love.mouse.isDown(2)
	end
	fps = love.timer.getFPS()
	if debug==true then
		if love.keyboard.isDown("up") then
			camera:move(0,-5)
		elseif love.keyboard.isDown("down") then
			camera:move(0,5)
		elseif love.keyboard.isDown("left") then
			camera:move(-5,0)
		elseif love.keyboard.isDown("right") then
			camera:move(5,0)
		end
	else
		camera:setPosition(0,0)
	end
	activeCleanup()
	mutationCycle()
	if fps < 10 then
		resetAll()
	end
end

function love.draw()
	camera:set()
	if cursor.mode==1 then
		if mouseDownL==true then
			if cursor.brushSize < 0 then cursor.brushSize=cursor.brushSize*-1 end
			if cursor.brushSize==0 or cursor.brushSize==1 then cursor.brushSize=cursor.brushSize+2 end
			newParticle(mouseX,mouseY,particleSize+cursor.brushSize*2,particleSize+cursor.brushSize)
			spawnGround()
		end

		if mouseDownR==true then
			--Body at mouse for pushing object
			if objects.mouse and objects.mouse.body:isDestroyed()==false then
				objects.mouse.body:setX(mouseX)
				objects.mouse.body:setY(mouseY)
			else
				objects.mouse={}
				objects.mouse.body=love.physics.newBody(world,mouseX,mouseY,"static")
				objects.mouse.shape=love.physics.newRectangleShape(0,0,200,200,0)
				objects.mouse.fixture=love.physics.newFixture(objects.mouse.body,objects.mouse.shape,1)
				objects.mouse.joint = love.physics.newMouseJoint( objects.mouse.body,0,0 )
			end

		else
			if objects.mouse and objects.mouse.body:isDestroyed()==false then
				objects.mouse.body:setX(-100)
				objects.mouse.body:setY(-100)
			end
		end
	end
	-- Draw the particles
	for i in pairs(particles) do
		if particles[i].body:isDestroyed()==false then
			if particles[i].flag==0 then -- Normal living Cells
				love.graphics.setColor(0,0,255)
				love.graphics.circle( "line",particles[i].body:getX() , particles[i].body:getY(), particles[i].shape:getRadius(), 30 )
			end

			if particles[i].flag==1 then  -- Mutated living Cells
				love.graphics.setColor(0,255,0)
				love.graphics.circle( "line",particles[i].body:getX() , particles[i].body:getY(), particles[i].shape:getRadius(), 20 )
			end

			if particles[i].flag==2 then --
			end

			if particles[i].flag==3 and particles[i].mut then -- Mutated dead Cells
				love.graphics.setColor(255,0,0)
				love.graphics.circle( "line",particles[i].body:getX() , particles[i].body:getY(), particles[i].shape:getRadius(), 20 )
			end
		end
	end
	-- Draw the preset Objects
	for i in pairs(objects) do
		if objects[i].body:isDestroyed()==false then
			love.graphics.setColor(255,255,255)
			love.graphics.polygon("line", objects[i].body:getWorldPoints(objects[i].shape:getPoints()))
		end
	end
	camera:unset()

	love.graphics.setColor(255,255,255)
	love.graphics.circle("line",mouseX,mouseY,particleSize+cursor.brushSize,50)
	love.graphics.print("FPS: "..fps,50,50)
	love.graphics.print("Total Spawned Bodies: "..pNextID,50,60)
	love.graphics.print("Deleted Particles: "..deletedParticles,50,70)
	love.graphics.print("mouseX: "..mouseX.." | mouseY: "..mouseY,50,80)
	love.graphics.print("Brush Size: "..cursor.brushSize,50,90)
	if lastKey then
		love.graphics.print("Last keypress: "..lastKey,50,100)
	end
	if debug==true then
		love.graphics.setColor(255,255,0)
		love.graphics.print("Debug mode ON",50,110)
	end
	love.graphics.setColor(255,255,255)
	if mutationChance >mutationThreshhold then
		love.graphics.setColor(0,255,0)
	end
	love.graphics.print("Mutation Chance: "..mutationChance.."%",50,120)
	love.graphics.print("Mutations: "..mutations,50,130)

	-- Hints 'n' stuff
	if hints==true then
		love.graphics.setColor(255,255,255)
		love.graphics.print("Hint: try to mash the (green) mutated Cells to try to cause fusion!\nAlso, smaller Cells are easier to make fusion with.",window_width/3.4,window_height/10)
	end
end

function love.keypressed(key)
    if (key == "escape") then
        love.event.quit()
    end
    if (key=="r") then
    	resetAll()
    end
    if (key=="d") then
    	debug=not(debug)
    end
    if (key=="g") then
    	objects.ground={}
    	objects.ground.body=love.physics.newBody(world,window_width/2,window_height,"static")
    	objects.ground.shape=love.physics.newRectangleShape(0,0,window_width+20,100,0)
		objects.ground.fixture=love.physics.newFixture(objects.ground.body,objects.ground.shape,1)
		print("Spawned a new Ground!")
		pNextID=pNextID+1
    end
    if (key=="h") then
    	hints=not(hints)
    end
    lastKey=key
end

function love.quit()
	gamestate=99
end
