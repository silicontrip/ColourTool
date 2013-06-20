//
//  MyOpenGLView.m
//  GoldenTriangle
//
//  Created by Mark Heath on 31/08/10.
//  Copyright 2010 
//

#import "MyOpenGLView.h"


@implementation MyOpenGLView

NSPoint normalY;
NSPoint normalZ;

#define MAXPOINTS 256

NSPoint delta;
static int yuv[MAXPOINTS][MAXPOINTS][MAXPOINTS];
int readFlag=0;
GLuint pointIndex;
GLfloat rotQuat [4];

NSTrackingRectTag trackingTag;

// quaternion multiplication.
// 0 = i, 1=j, 2=k, 3=w
void quatmult( float r[4], float q1[4], float q2[4]) 
{
	
	r[0] = q1[3] * q2[0] + q1[0] * q2[3] + q1[1] * q2[2] - q1[2] * q2[1];
	r[1] = q1[3] * q2[1] + q1[1] * q2[3] + q1[2] * q2[0] - q1[0] * q2[2];
	r[2] = q1[3] * q2[2] + q1[2] * q2[3] + q1[0] * q2[1] - q1[1] * q2[0];
	r[3] = q1[3] * q2[3] - q1[0] * q2[0] - q1[1] * q2[1] - q1[2] * q2[2];
	
}

void quat2axisang (float *x, float *y, float *z, float *th, float q[4]) 
{

	float scale = sqrt (q[0] * q[0] + q[1] * q[1] + q[2] * q[2]);
	
	*th = 2 * acosf(q[3]);
	*x = q[0] / scale;
	*y = q[1] / scale;
	*z = q[2] / scale;

}

void quatpointmult ( float r[3], float q1[4], float q2[4]) 
{
	r[0] = (q1[3]*q2[0] +q1[0]*q2[3] +q1[1]*q2[2] -q1[2]*q2[1]);  // matches above
	r[1] = (q1[3]*q2[1] +q1[1]*q2[3] +q1[2]*q2[0] -q1[0]*q2[2]);  // matches above
	r[2] = (q1[3]*q2[2] +q1[2]*q2[3] +q1[0]*q2[1] -q1[1]*q2[0]);  // matches above
}

void quatnorm ( float q[4] ) 
{
	
	float mag2 = q[3] * q[3] + q[0] * q[0] + q[1] * q[1] + q[2] * q[2];
	if (  mag2!=0.f && (fabs(mag2 - 1.0f) > 0.000001)) {
		float mag = sqrt(mag2);
		q[0] /= mag;
		q[1] /= mag;
		q[2] /= mag;
		q[3] /= mag;
	} 
	
}

void quat2matrix (float m[16], float q[4]) 
{
	
	// convert the display quaternion to a transformation matrix.
	float x2 = q[0] * q[0];
	float y2 = q[1] * q[1];
	float z2 = q[2] * q[2];
	float xy = q[0] * q[1];
	float xz = q[0] * q[2];
	float yz = q[1] * q[2];
	float wx = q[3] * q[0];
	float wy = q[3] * q[1];
	float wz = q[3] * q[2];
	
	m[0] = 1.0f - 2.0f * (y2 + z2);
	m[1] = 2.0f * (xy - wz);
	m[2] = 2.0f * (xz + wy);
	m[3] = 0.0f;
	m[4] = 2.0f * (xy + wz);
	m[5] = 1.0f - 2.0f * (x2 + z2);
	m[6] = 2.0f * (yz - wx);
	m[7] = 0.0f;
	m[8] = 2.0f * (xz - wy);
	m[9] = 2.0f * (yz + wx);
	m[10] = 1.0f - 2.0f * (x2 + y2);
	m[11] = 0.0f;
	m[12] = 0.0f;
	m[13] = 0.0f;
	m[14] = 0.0f;
	m[15] = 1.0f;
	
}

void rgb2vert (int inv, int r, int g, int b, int *x, int *y, int *z) 
{

	float sina,cosa;
	float rot[4];
	float point[4];
	float conj[4];
	float temp[4];
	float outpoint[4];
	
	// compute quaternion from axis+angle
	//sina = inv * sqrt(2) / 2; // this is constant
	
	sina =  sin (20	* M_PI / 180);
	cosa =  cos (20 * M_PI / 180);
	
	rot[0] = -sina;
	rot[1] = 0;
	rot[2] = sina;
	rot[3] = cosa;
		
	point[0] = r-128;
	point[1] = g-128;
	point[2] = b-128;
	point[3] = 0;
	
	conj[0] = -rot[0];
	conj[1] = -rot[1];
	conj[2] = -rot[2];
	conj[3] =  rot[3];

	quatmult(temp,point,conj);
	quatmult(outpoint, rot, temp);

	*x = (outpoint[0] + 224) * 4 / 7;
	*y = (outpoint[1] + 248) * 64 / 123;
	*z = (outpoint[2] + 224) * 4 / 7;
//	NSLog(@" out point %d %d %d - %d %d %d\n",r,g,b, *x, *y, *z);
	
}
	
void rgb2yuv (int r, int g, int b, int *y, int *u, int *v) 
{
	
	*y =((16843 * r) + (33030 * g) + (6423 * b)>>16) + 16;
	*u =(-(9699 * r) - (19071 * g) + (28770 * b)>>16) + 128;
	*v =((28770 * r) - (24117 * g) - (4653 * b)>>16) + 128;
	
}	

void yuv2rgb (int y, int u, int v, int *r, int *g, int *b)
{
	
	// want to convert this to integer maths.
	*b = 1.164*(y - 16) + 2.018*(u - 128);
	*g = 1.164*(y - 16) - 0.813*(v - 128) - 0.391*(u - 128);
	*r = 1.164*(y - 16) + 1.596*(v - 128);
	
}

void readPoints () 
{
	
	FILE *fd;
	unsigned char buf[32];
	int y,u,v,w,h,p,c,r;
	
	fd = stdin;
	
	fread (buf,2,1,fd);
	if (buf[0] != 'P' || buf[1] != '6') {
		NSLog(@"Not a Binary PPM file (p6)\n");
		exit(1);
	}
	
	// read width and height
	fscanf(fd,"%d %d",&w,&h);
	p  = w * h;
	NSLog (@"wid: %d hei: %d pixels: %d\n",w,h,p);
	
	// read brightness
	fscanf(fd,"%d",&v);
	if (v != 255 ) {
		NSLog(@"Not an 8 bit image\n");
		exit(1);
	}
	
	for (y=0;y<MAXPOINTS;y++)
		for(u=0;u<MAXPOINTS;u++)
			for (v=0;v<MAXPOINTS;v++)
				yuv[y][u][v]=0;
	
	fread (buf,1,1,fd);
	// run histogram
	for (c=0; c <p; c++) {
		//		r=read(fd,buf,3);
		r=fread(buf,1,3,fd);
		if (r == 3) {
			
			y=0; u=0; v=0;
			
			// translate points
			
			//rgb2vert(1,buf[0], buf[1], buf[2], &y,&u,&v);
			
			y=buf[1]; u=buf[0]; v=buf[2];
			
			if (u>=0 && u< MAXPOINTS && y>=0 && y < MAXPOINTS && v>=0 && v<=MAXPOINTS) {
				yuv[u][y][v]++;
			}
		}
		else {
			NSLog(@"Only read %d bytes\n",r);
			perror ("read");
		}
	}
	// find max val
	fclose (fd);
	NSLog (@"Bytes read\n");
	
}


static void drawGridPoints() 
{
	
	int y,u,v;
	float fy,fu,fv;
	int r,g,b;
		
	glColor3f(1.0f, 1.0f, 1.0f);
		
	glBegin(GL_POINTS);

	for (y=0;y<MAXPOINTS;y+=16)
		for(u=0;u<MAXPOINTS;u+=16)
			for (v=0;v<MAXPOINTS;v+=16)
			{
				rgb2vert(-1, y, u, v, &r, &g, &b);
					fy = r / 256.0 - 0.5;
					fu = g / 256.0 - 0.5;
					fv = b / 256.0 - 0.5 ;
					//yuv2rgb(y,u,v,&r,&g,&b);
					glColor3f(r/255.0, g/255.0,b/255.0);
					glVertex3f(fu,fy,fv);
			}
	glEnd();
	
}


void addPoint(int y, int u, int v) 
{
	float fy = y - 0.5;
	float fu = u - 0.5;
	float fv = v - 0.5 ;
	//yuv2rgb(y,u,v,&r,&g,&b);
	glColor3ub(y*255,u*255,v*255);
	glVertex3f(fu,fy,fv);
}

static void drawPoints() 
{	
	glCallList(pointIndex);
}

static void drawBox ()
{
	
	glPolygonMode(GL_FRONT_AND_BACK,GL_LINE);
	glCallList(pointIndex+1);

}


void createPoints () 
{
	
	int y,u,v,r,g,b;
	
	pointIndex = glGenLists(2);
	
	glNewList(pointIndex, GL_COMPILE);
	glBegin(GL_POINTS);
	
	for (y=0;y<MAXPOINTS;y++)
		for(u=0;u<MAXPOINTS;u++)
			for (v=0;v<MAXPOINTS;v++)
				// want to make selectable percentile
				if (yuv[y][u][v] > 5) {
					//NSLog (@"point\n");
					
					float fy = y / 256.0 - 0.5;
					float fu = u / 256.0 - 0.5;
					float fv = v / 256.0 - 0.5 ;
					// yuv2rgb(y,u,v,&r,&g,&b);
					// rgb2vert(-1,y,u,v, &r,&g,&b);
					
 					r=y;g=u;b=v;
					glColor3ub(r,g,b);
					glVertex3f(fu,fy,fv);
				}
	glEnd();
	
	glEndList();
	
	glNewList(pointIndex+1, GL_COMPILE);
	
	glBegin(GL_QUADS);
    {
		
		addPoint(0,0,0);
		addPoint(0,1,0);
		addPoint(1,1,0);
		addPoint(1,0,0);
		
		addPoint(0,0,0);
		addPoint(0,0,1);
		addPoint(0,1,1);
		addPoint(0,1,0);
		
		addPoint(0,0,0);
		addPoint(1,0,0);
		addPoint(1,0,1);
		addPoint(0,0,1);
		
		addPoint(1,1,1);
		addPoint(1,0,1);
		addPoint(1,0,0);
		addPoint(1,1,0);
		
		addPoint(1,1,1);
		addPoint(1,1,0);
		addPoint(0,1,0);
		addPoint(0,1,1);
		
		addPoint(1,1,1);
		addPoint(0,1,1);
		addPoint(0,0,1);
		addPoint(1,0,1);
		
	}
	glEnd();
	glEndList();
	
}	

void simPoints() 
{
	
	int y,u,v,c;
	
	for (y=0;y<MAXPOINTS;y++)
		for(u=0;u<MAXPOINTS;u++)
			for (v=0;v<MAXPOINTS;v++)
				yuv[y][u][v]=0;
	
	for (c=0; c<MAXPOINTS; c++) {
		
		rgb2vert(1, c, c, c, &y,&u,&v);
		
		if (u>=0 && u< MAXPOINTS && y>=0 && y < MAXPOINTS && v>=0 && v<=MAXPOINTS) {
			yuv[u][y][v]=50;
		}
	}
}


- (id) init
{
    if ((self = [super init])) {
        /* class-specific initialization goes here */
		NSLog ( @"init\n");
    }
    return self;
}

-(id)initWithFrame:(NSRect)rect 
{	
	[super initWithFrame: rect];
    return self;
}


- (void)mouseDown:(NSEvent *) theEvent
{
	delta = [theEvent locationInWindow];
}

- (void)mouseDragged:(NSEvent *)theEvent
{

	GLfloat transformationMatrix[16];
	NSPoint mouse;
	float angleX, angleY;
	GLfloat mouseRot[4];
	GLfloat tempRot[4];
	
	mouse = [theEvent locationInWindow];

	// add this to the rotational quaternion.

	angleY = mouse.x - delta.x;  // pitch
	angleX = -mouse.y + delta.y; // roll

	// calculate the mouse rotational quaternion
	float sinay = sin(angleY / 360 * M_PI );
	float sinax = sin(angleX / 360 * M_PI );
	
	float cosay = cos(angleY / 360 * M_PI);
	float cosax = cos(angleX / 360 * M_PI);
	
	// will optimise later, when I know this code works.
	mouseRot[0] = sinax;
	mouseRot[1] = 0;
	mouseRot[2] = 0;
	mouseRot[3] = cosax;
	
	// multiply it with the display rotational quaternion	
	quatmult(tempRot,rotQuat,mouseRot);
	
	mouseRot[0] = 0;
	mouseRot[1] = sinay;
	mouseRot[2] = 0;
	mouseRot[3] = cosay;
	
	quatmult(rotQuat,tempRot,mouseRot);
	// normalise the display quaternion
	quatnorm(rotQuat);
	
	// convert the display quaternion to a transformation matrix.
	quat2matrix(transformationMatrix,rotQuat);
	glMatrixMode(GL_MODELVIEW);
	
	glLoadMatrixf(transformationMatrix);
	
	delta = mouse;
	
	[self setNeedsDisplay:TRUE];
	
}

- (void)mouseEntered:(NSEvent *)theEvent {
	// NSLog(@"mouse Entered...\n");
	[[self window] setAcceptsMouseMovedEvents:YES];
}

- (void)mouseExited:(NSEvent *)theEvent {
	//NSLog(@"mouse exit...\n");
	[[self window] setAcceptsMouseMovedEvents:NO];
}


- (void)mouseMoved:(NSEvent *)theEvent {
	// NSLog(@"mouse moved...\n");
	
	// read pixel, 
	// if not grey
	// display rgb (other colour spaces)
	// display histogram count.
}

- (void) openFile:(NSURL *)fn
{

	int y,u,v,w,h,p,m,n,s;
	
	NSImage *loadImage = [[NSImage alloc] initWithContentsOfURL:fn];
	NSBitmapImageRep *imageRep = [[loadImage representations] objectAtIndex:0];
	NSUInteger pixel[4];
    
    
//	unsigned char *pixelData = [imageRep bitmapData];

	w = [imageRep pixelsWide];
	h = [imageRep pixelsHigh];
	p = [imageRep bytesPerRow];
	s = [imageRep samplesPerPixel];
	
	for (n=0; n<h; n++) 
        for (m=0; m<w; m++)
	{
        [imageRep getPixel:pixel atX:m y:n];
		yuv[pixel[0]][pixel[1]][pixel[2]]++;

	}
	
	//NSLog(@"finished reading");
	[loadImage dealloc];
	
	createPoints();
	readFlag=1;
	[self setNeedsDisplay:TRUE];

	
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	
    // We always want the Preview... item to enabled when there is a
    // document open.
    // Note that we use the action to compare against, not the string
    // this allows for language localization
    if ([anItem action] == @selector(openDocument:))
    {
        return YES;
    }
	
    // if it isn't one of our menu items, we'll let the
    // superclass take care of it
    return [super validateMenuItem:anItem];
}

- (void)openDocument:sender
{
	// NSLog ( @"we will we will open");
	
	NSOpenPanel *open = [NSOpenPanel openPanel];
		
	int result = [open runModal];
	
	if (result == NSOKButton){
		
		NSURL *selectedFile = [[open URLs] lastObject];
		//NSLog ( @"File selected: %@", selectedFile);
		
		[self openFile: selectedFile];
	}
}


-(void) drawRect: (NSRect) bounds
{
	
	
/*	
	GLfloat lightColor0[] = {1.0f, 1.0f, 1.0f, 1.0f}; //Color (0.5, 0.5, 0.5)
    GLfloat lightPos0[] = {0.0f, 0.0f, 0.0f, 1.0f}; //Positioned at (4, 0, 8)
	
    glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);
    glEnable(GL_COLOR_MATERIAL);
*/	
//	glutInitDisplayMode( GLUT_RGB | GLUT_DEPTH  );
	glEnable(GL_DEPTH_TEST);
//	glDepthFunc (GL_LESS);
	
	/*
	if (readFlag ==0) {
		createPoints();
		readFlag=1;
	}
	*/
	
	glViewport(0,0, bounds.size.width, bounds.size.height);
	
    glClearColor(0.5, 0.5, 0.5, 0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
//	glLightfv(GL_LIGHT0, GL_DIFFUSE, lightColor0);
//  glLightfv(GL_LIGHT0, GL_POSITION, lightPos0);
	
	glMatrixMode(GL_MODELVIEW);
	//gluPerspective(45.0, 1, 1.0, 200.0);
	
	if (readFlag) {
		drawBox();
		drawPoints();
	} 
	
	// trackingTag = [self addTrackingRect:bounds owner:[self window] userData:nil assumeInside:NO];
	
	//	drawGridPoints();
    glFlush();
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void) viewDidMoveToWindow {
	trackingTag = [self addTrackingRect:[self bounds]
							owner:self
						 userData:nil
					 assumeInside:NO];
}


-(void) awakeFromNib {
	
	int y,u,v;
	
	//simPoints();
// 	readPoints();
	
	rotQuat[0] = 0;
	rotQuat[1] = 0;
	rotQuat[2] = 0;
	rotQuat[3] = 1;
	
	for (y=0;y<MAXPOINTS;y++)
		for(u=0;u<MAXPOINTS;u++)
			for (v=0;v<MAXPOINTS;v++)
				yuv[y][u][v]=0;
	
	[[self window] makeFirstResponder: self];
	
//	trackingTag = [self addTrackingRect:[self  frame] owner:[self window] userData:nil assumeInside:NO];

// NSLog(@"Tracking Tag: %d rect: %@", trackingTag,[[self window] frame]);

//	[[self window] setAcceptsMouseMovedEvents:YES];
	
	/*
	rgb2vert(-1, 0,0, 0, &x, &y, &z);
	NSLog(@"rgb 0,0,0 XYZ - %d %d %d\n",x,y,z);
	rgb2vert(-1, 255,0, 0, &x, &y, &z);
	NSLog(@" 255,0,0 XYZ - %d %d %d\n",x,y,z);
	rgb2vert(-1, 255,255, 0, &x, &y, &z);
	NSLog(@" 255,255,0 XYZ - %d %d %d\n",x,y,z);
	rgb2vert(-1, 0,255, 0, &x, &y, &z);
	NSLog(@" 0,255,0 XYZ - %d %d %d\n",x,y,z);

	
	rgb2vert(-1, 0,255, 255, &x, &y, &z);
	NSLog(@" 0,255,255 XYZ - %d %d %d\n",x,y,z);
	rgb2vert(-1, 0,0, 255, &x, &y, &z);
	NSLog(@"0,0,255 XYZ - %d %d %d\n",x,y,z);
	rgb2vert(-1, 255,255, 255, &x, &y, &z);
	NSLog(@"255.255.255 XYZ - %d %d %d\n",x,y,z);
	rgb2vert(-1, 255,0, 255, &x, &y, &z);
	NSLog(@" 255,0,255 XYZ - %d %d %d\n",x,y,z);
	 */
	
	
}


@end
