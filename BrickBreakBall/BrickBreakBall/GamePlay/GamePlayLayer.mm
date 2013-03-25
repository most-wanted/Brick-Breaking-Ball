//
//  GamePlayLayer.m
//  BrickBreakBall
//
//  Created by Hossam on 3/21/13.
//  Copyright 2013 __MyCompanyName__. All rights reserved.
//

#import "GamePlayLayer.h"


@implementation GamePlayLayer

-(id)init
{
    if ((self = [super init])) {
        
        self.isTouchEnabled = YES;
        
        [[[CCDirector sharedDirector] touchDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
        
        size = [[CCDirector sharedDirector] winSize];
        upperBarHeight = 60.0f;
        //load sprite sheet
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"bricksheet.plist"];
        bricksSheet = [CCSpriteBatchNode batchNodeWithFile:@"bricksheet.png" capacity:100];
        [self addChild:bricksSheet z:1];
        
        //add the background image
        CCSprite *backGround = [CCSprite spriteWithSpriteFrameName:@"brick_bg.png"];
        backGround.position = ccp(size.width / 2,
                                  size.height / 2);
        [self addChild:backGround z:-2];
        
        
        [self setUpWorld];
        [self buildEdges];
        
        //contact listener
        
        contactListener = new BRContactListener();
        world ->SetContactListener(contactListener);
        
        [self schedule:@selector(update:)];
        
        

    
    }
    return self;
}

-(void)onEnterTransitionDidFinish
{
    [self addNewBall];
    [self buildPaddleAtPosition:CGPointMake(size.width / 2 + 40, size.height / 4)];
    
}

-(void)update:(ccTime)dt
{
    world->Step(dt, 10, 10);
    
    for (b2Body *b = world->GetBodyList() ; b; b = b->GetNext() ) {
        
        if (b->GetUserData() != NULL) {
            PhysicsSprite *physicsSprite = (PhysicsSprite *) b->GetUserData();
            if (physicsSprite.tag == BALL) {
                
                
                b2Vec2 velocity = b ->GetLinearVelocity();
                float32 speed = velocity.Length();
                
                int maxSpeed = 25;
                if (speed > maxSpeed) {
                    b->SetLinearDamping(0.5);
                }
                else if (speed < maxSpeed)
                {
                    b->SetLinearDamping(0);
                }
            }
        }
        
    }
    
    //check for collision with buttom
    vector<b2Body *>toBeDestroyed;
    vector<BRContact>::iterator pos;
    
    for (pos = contactListener->_contacts.begin(); pos != contactListener->_contacts.end(); pos++) {
        
        BRContact contact = *pos; //means the collision between bodies
        //get the bodies
        b2Body *body1 = contact.fixtureA -> GetBody();
        b2Body *body2 = contact.fixtureB -> GetBody();
        
        //get the sprites
        PhysicsSprite *sprite1 = (PhysicsSprite *)body1->GetUserData();
        PhysicsSprite *sprite2 = (PhysicsSprite *)body2->GetUserData();
        
        if (sprite1.tag == BALL && contact.fixtureB == bottomGutter) {
            if (find(toBeDestroyed.begin(), toBeDestroyed.end(), body1) == toBeDestroyed.end()) {
                
                toBeDestroyed.push_back(body1);
                
                NSLog(@"collision");
            }
        }
        else if (sprite2.tag == BALL && contact.fixtureA == bottomGutter)
        {
            if (find(toBeDestroyed.begin(), toBeDestroyed.end(), body2) == toBeDestroyed.end()) {
                
                toBeDestroyed.push_back(body2);
                NSLog(@"collision");
            }
        }
        //iterate over toBeDestroyed
    }
    
    vector<b2Body *>::iterator pos2;
    for (pos2 = toBeDestroyed.begin(); pos2 != toBeDestroyed.end(); pos2 ++) {
        b2Body *body = *pos2;
        
        if (body -> GetUserData() != NULL) {
            //get the physics sprite
            PhysicsSprite *destroyedSprite = (PhysicsSprite *)body -> GetUserData();
            [self destroySprite:destroyedSprite];
        }
        world -> DestroyBody(body);
    }

}


-(void)destroySprite:(PhysicsSprite *)sprite
{
    switch (sprite.tag) {
        case BALL:
            [[SimpleAudioEngine sharedEngine] playEffect:SND_LOSEBALL];
            [sprite removeFromParentAndCleanup:YES];
            //lose life
            break;
            
        default:
            break;
    }
}



-(void)setUpWorld
{
    b2Vec2 gravity;
    gravity.Set(0, 0);
    world = new b2World(gravity);
    
    world->SetAllowSleeping(true);
    world->SetContinuousPhysics(true);
    
    //creating the contact listener here
}


-(void)buildEdges
{
    //define and creating the wall body
    b2BodyDef wallBodyDef;
    wallBodyDef.position.Set(0, 0);
    wallBody = world->CreateBody(&wallBodyDef);
    
    //create 4 corners

    b2Vec2 bl(0.0f, 0.0f); //bottom_left
    b2Vec2 br(size.width / PTM_RATIO, 0.0f); //bottom_right  //devide on PTM_RATIO to convert from cocos2d location to box2d location
    
    b2Vec2 ul(0.0f, (size.height - upperBarHeight) / PTM_RATIO); //upper_left
    b2Vec2 ur(br.x, ul.y); //upper_right
    
    b2EdgeShape bottomEdge, leftEdge, upperEdge, rightEdge;  //gamePlay edges
    
    bottomEdge.Set(bl, br);
    leftEdge.Set(bl, ul);
    upperEdge.Set(ul, ur);
    rightEdge.Set(br, ur);
    
    wallBody->CreateFixture(&leftEdge, 0);
    wallBody->CreateFixture(&upperEdge, 0);
    wallBody->CreateFixture(&rightEdge, 0);
    
    bottomGutter = wallBody->CreateFixture(&bottomEdge, 0); //we have the b2fixture to be used in collison with ball (lose)
    
}

-(void)buildPaddleAtPosition:(CGPoint)position
{
    playerPaddle = [PhysicsSprite spriteWithSpriteFrameName:@"paddle.png"];
    playerPaddle.position = position;
    playerPaddle.tag = PADDLE;
    
    [bricksSheet addChild:playerPaddle];
    
    b2BodyDef bodyDef;
    bodyDef.position.Set(position.x / PTM_RATIO, position.y / PTM_RATIO);
    bodyDef.type = b2_dynamicBody;
    bodyDef.userData = playerPaddle;
    
    paddleBody =  world ->CreateBody(&bodyDef);
    [playerPaddle setPhysicsBody:paddleBody];
    
    [self buildPaddleFixtureNormal];
    
    //
    
    
    b2PrismaticJointDef joint;
    b2Vec2 worldAxis(1.0f, 0.0f);
    joint.collideConnected = true;
    joint.Initialize(paddleBody, wallBody, paddleBody -> GetWorldCenter(), worldAxis);
    world -> CreateJoint(&joint);
    
}
//create the fixture of paddle in normal state
-(void)buildPaddleFixtureNormal
{
    //define paddle shap
    b2PolygonShape paddleShape;
    int num = 8;
    b2Vec2 verts[] = {
        b2Vec2(31.5f / PTM_RATIO, -7.5f / PTM_RATIO),
        b2Vec2(31.5f / PTM_RATIO, -0.5f / PTM_RATIO),
        b2Vec2(30.5f / PTM_RATIO, 0.5f / PTM_RATIO),
        b2Vec2(22.5f / PTM_RATIO, 6.5f / PTM_RATIO),
        b2Vec2(-24.5f / PTM_RATIO, 6.5f / PTM_RATIO),
        b2Vec2(-31.5f / PTM_RATIO, 1.5f / PTM_RATIO),
        b2Vec2(-32.5f / PTM_RATIO, 0.5f / PTM_RATIO),
        b2Vec2(-32.5f / PTM_RATIO, -7.5f / PTM_RATIO),
    };
    paddleShape.Set(verts, num);
    
    [self buildPaddleFixtureWithShape:paddleShape
                   andSpriteFrameName:@"paddle.png"];
}


-(void)buildPaddleFixtureWithShape:(b2PolygonShape)shape andSpriteFrameName:(NSString *)frameName
{
    if (paddleFixture != nil) {
        paddleBody -> DestroyFixture(paddleFixture);
    }
    
    b2FixtureDef paddleFixtureDef;
    paddleFixtureDef.shape = &shape;
    paddleFixtureDef.restitution = 0 ;
    paddleFixtureDef.density = 50.0f;
    paddleFixtureDef.friction = 0;
    
    paddleFixture = paddleBody -> CreateFixture(&paddleFixtureDef);
    
    [playerPaddle setDisplayFrame:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:frameName]];
}

-(void)addNewBall
{
    //give kick down and right
    [self createBallAtPosition:ccp(200, 150) andInitialImpulse:b2Vec2(0.2, -1.5)];
}

-(void)createBallAtPosition:(CGPoint)position andInitialImpulse:(b2Vec2)impulse
{
    PhysicsSprite *ball = [PhysicsSprite spriteWithSpriteFrameName:@"ball.png"];
    ball.position = position;
    ball.tag = BALL;
    [bricksSheet addChild:ball z:50];
    
    //create ball body (body created with position and type)
    b2BodyDef ballBodyDef;
    ballBodyDef.position.Set(position.x / PTM_RATIO, position.y / PTM_RATIO);
    ballBodyDef.type = b2_dynamicBody;
    ballBodyDef.userData = ball;
    
    b2Body *ballBody = world->CreateBody(&ballBodyDef);
    [ball setPhysicsBody:ballBody];
    
    b2CircleShape circleShape;
    circleShape.m_radius = 7.0 / PTM_RATIO;
    
    b2FixtureDef ballFixtureDef;
    ballFixtureDef.shape = &circleShape;
    ballFixtureDef.density = 1.0f;
    ballFixtureDef.friction = 0.0f;
    ballFixtureDef.restitution = 1.0f; //perfect bouncy
    
    ballBody->CreateFixture(&ballFixtureDef);
    //add an impulse (kick) to the ball to move
    ballBody->ApplyLinearImpulse(impulse, ballBody->GetPosition());
    
}

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
    
    if (mouseJoint != NULL) {
        return YES;
    }
    
    CGPoint location = [touch locationInView:touch.view];
    location = [[CCDirector sharedDirector] convertToGL:location];
    b2Vec2 locationInWorld(location.x / PTM_RATIO, location.y / PTM_RATIO);
    
    //touches under the paddle area
    if (location.y <= size.height / 4) {
        b2MouseJointDef mjd;
        mjd.bodyA = wallBody;
        mjd.bodyB = paddleBody;
        mjd.collideConnected = true;
        mjd.target = locationInWorld;
        
        mjd.maxForce = 1000.0f * paddleBody -> GetMass();
        mouseJoint = (b2MouseJoint *)world -> CreateJoint(&mjd);
        
        paddleBody -> SetAwake(true);
    }
    
    
    return YES;
}
// touch updates:
- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (mouseJoint == NULL || isGameOver) {
        return;
    }
    
    CGPoint location = [touch locationInView:touch.view];
    location = [[CCDirector sharedDirector] convertToGL:location];
    b2Vec2 locationInWorld(location.x / PTM_RATIO, location.y / PTM_RATIO);
    mouseJoint ->SetTarget(locationInWorld);
}
- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (mouseJoint != NULL) {
        world -> DestroyJoint(mouseJoint);
        mouseJoint = NULL;
    }
    
}
- (void)ccTouchCancelled:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (mouseJoint != NULL) {
        world -> DestroyJoint(mouseJoint);
        mouseJoint = NULL;
    }
}


@end