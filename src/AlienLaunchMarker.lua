--[[
    GD50
    Angry Birds

    Author: Colton Ogden
    cogden@cs50.harvard.edu
]]

AlienLaunchMarker = Class{}

function AlienLaunchMarker:init(world)
    self.world = world

    -- starting coordinates for launcher used to calculate launch vector
    self.baseX = 90
    self.baseY = VIRTUAL_HEIGHT - 100

    -- shifted coordinates when clicking and dragging launch alien
    self.shiftedX = self.baseX
    self.shiftedY = self.baseY

    -- whether our arrow is showing where we're aiming
    self.aiming = false

    -- whether we launched the alien and should stop rendering the preview
    self.launched = false

    -- our alien we will eventually spawn
    self.aliens = {}
    self.hasBeenHit = false
    self.hasSplit = false
end

function AlienLaunchMarker:update(dt)
    
    -- perform everything here as long as we haven't launched yet
    if not self.launched then

        -- grab mouse coordinates
        local x, y = push:toGame(love.mouse.getPosition())
        
        -- if we click the mouse and haven't launched, show arrow preview
        if love.mouse.wasPressed(1) and not self.launched then
            self.aiming = true

        -- if we release the mouse, launch an Alien
        elseif love.mouse.wasReleased(1) and self.aiming then
            self.launched = true

            self:createAlien({
                x = self.shiftedX,
                y = self.shiftedY,
                dx = (self.baseX - self.shiftedX) * 10,
                dy = (self.baseY - self.shiftedY) * 10
            })

            -- we're no longer aiming
            self.aiming = false

        -- re-render trajectory
        elseif self.aiming then
            
            self.shiftedX = math.min(self.baseX + 30, math.max(x, self.baseX - 30))
            self.shiftedY = math.min(self.baseY + 30, math.max(y, self.baseY - 30))
        end
    end
end

function AlienLaunchMarker:render()
    if not self.launched then
        
        -- render base alien, non physics based
        love.graphics.draw(gTextures['aliens'], gFrames['aliens'][9], 
            self.shiftedX - 17.5, self.shiftedY - 17.5)

        if self.aiming then
            
            -- render arrow if we're aiming, with transparency based on slingshot distance
            local impulseX = (self.baseX - self.shiftedX) * 10
            local impulseY = (self.baseY - self.shiftedY) * 10

            -- draw 18 circles simulating trajectory of estimated impulse
            local trajX, trajY = self.shiftedX, self.shiftedY
            local gravX, gravY = self.world:getGravity()

            -- http://www.iforce2d.net/b2dtut/projected-trajectory
            for i = 1, 90 do
                
                -- magenta color that starts off slightly transparent
                love.graphics.setColor(255/255, 80/255, 255/255, ((255 / 24) * i) / 255)
                
                -- trajectory X and Y for this iteration of the simulation
                trajX = self.shiftedX + i * 1/60 * impulseX
                trajY = self.shiftedY + i * 1/60 * impulseY + 0.5 * (i * i + i) * gravY * 1/60 * 1/60

                -- render every fifth calculation as a circle
                if i % 5 == 0 then
                    love.graphics.circle('fill', trajX, trajY, 3)
                end
            end
        end
        
        love.graphics.setColor(1, 1, 1, 1)
    else
        for k,alien in pairs(self.aliens) do
            alien:render()
        end
    end
end

--[[
    Params needed in this function are:
        x, y, dx, dy
]]
function AlienLaunchMarker:createAlien(params)
    -- spawn new alien in the world, passing in user data of player
    local alien = Alien(self.world, 'round', params.x, params.y, 'Player')

    -- apply the difference between current X,Y and base X,Y as launch vector impulse
    alien.body:setLinearVelocity(params.dx, params.dy)

    -- make the alien pretty bouncy
    alien.fixture:setRestitution(0.4)
    alien.body:setAngularDamping(1)

    table.insert(self.aliens, alien)
end

function AlienLaunchMarker:areAliensMoving()
    for k,alien in pairs(self.aliens) do
        local xPos, yPos = alien.body:getPosition()
        local xVel, yVel = alien.body:getLinearVelocity()
        
        -- if alien is out of screen or it's almost done rolling, respawn
        if xPos > 0 and yPos < VIRTUAL_WIDTH and (math.abs(xVel) + math.abs(yVel) > 1.5) then
            return true
        end
    end
    return false
end

function AlienLaunchMarker:splitAlien()
    if self.aliens[1] == nil then
        return
    end

    local xPos, yPos = self.aliens[1].body:getPosition()
    local xVel, yVel = self.aliens[1].body:getLinearVelocity()
    local angle = 20

    local newAlien1Dx, newAlien1Dxy = self:getRotatedSpeed(xVel, yVel, angle)
    
    self:createAlien({
        x = xPos,
        y = yPos,
        dx = newAlien1Dx,
        dy = newAlien1Dxy
    })

    local newAlien2Dx, newAlien2Dxy = self:getRotatedSpeed(xVel, yVel, -angle)
    
    self:createAlien({
        x = xPos,
        y = yPos,
        dx = newAlien2Dx,
        dy = newAlien2Dxy
    })

    self.hasSplit = true
    gSounds['split-alien']:play()
end

function AlienLaunchMarker:getRotatedSpeed(dx, dy, angle)
    local sin = math.sin(angle * DEGREES_TO_RADIANS)
    local cos = math.cos(angle * DEGREES_TO_RADIANS)

    local newDx = dx * cos - dy * sin
    local newDy = dx * sin + dy * cos

    return newDx, newDy
end