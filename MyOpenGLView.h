//
//  MyOpenGLView.h
//  GoldenTriangle
//
//  Created by Mark Heath on 31/08/10.
//  Copyright 2010 Telstra. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#include <OpenGL/gl.h>
#include <GLUT/glut.h>
#include <math.h>

@interface MyOpenGLView : NSOpenGLView {

}

// quaternion functions
void quatmult( float r[4], float q1[4], float q2[4]) ;
void quat2axisang (float *x, float *y, float *z, float *th, float q[4]);
void quatpointmult ( float r[3], float q1[4], float q2[4]); 
void quatnorm ( float q[4] ) ;
void quat2matrix (float m[16], float q[4]); 

// Colour conversion functions

void rgb2vert (int inv, int r, int g, int b, int *x, int *y, int *z); 
void rgb2yuv (int r, int g, int b, int *y, int *u, int *v);
void yuv2rgb (int y, int u, int v, int *r, int *g, int *b);

void readPoints () ;

// 3d objects 

static void drawGridPoints() ;
void addPoint(int y, int u, int v); 
static void drawPoints(); 
static void drawBox();
void createPoints (); 
void simPoints() ;


// class methods

- (id) init;
- (id) initWithFrame: (NSRect)rect;

- (void) drawRect: (NSRect) bounds;


- (void)mouseDown:(NSEvent *) theEvent;
- (void)mouseDragged:(NSEvent *)theEvent;
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;

- (void)mouseMoved:(NSEvent *)theEvent;

- (BOOL)acceptsFirstResponder;

- (void) openFile:(NSURL *)fn;
- (BOOL)validateMenuItem:(NSMenuItem *)anItem;

- (void)openDocument:sender;
- (void) awakeFromNib;


@end
