//
//  GradientPolylineRenderer.m
//  mapDemo
//
//  Created by bravo on 13-11-21.
//  Copyright (c) 2013年 bravo. All rights reserved.
//

#import "GradientPolylineRenderer.h"
#import <pthread.h>
#import "GradientPolylineOverlay.h"

#define V_MAX 4.0
#define V_MIN 2.0
#define H_MAX 0.3
#define H_MIN 0.03

@interface GradientPolylineRenderer(FileInternal){
    
}
- (CGPathRef)newPathForPoints:(MKMapPoint *)points
                   pointCount:(NSUInteger)pointCount
                     clipRect:(MKMapRect)mapRect
                    zoomScale:(MKZoomScale)zoomScale
                        value:(CGFloat*)v;

@end

@implementation GradientPolylineRenderer{
    float* hues;
    pthread_rwlock_t rwLock;
    GradientPolylineOverlay* polyline;
}

-(id) initWithOverlay:(id<MKOverlay>)overlay{
    self = [super initWithOverlay:overlay];
    if (self){
        pthread_rwlock_init(&rwLock,NULL);
        polyline = ((GradientPolylineOverlay*)self.overlay);
        float *velocity = polyline.velocity;
        int count = polyline.pointCount;
        [self velocity:velocity ToHue:&hues count:count];
    }
    return self;
}
/**
 *  Convert velocity to Hue using specific formular.
 *
 *  H(v) = Vmax, (v > Vmax)
 *       = Vmin + ((v-Vmin)*(Hmax-Hmin))/(Vmax-Vmin), (Vmin <= v <= Vmax)
 *       = Vmin, (v < Vmin)
 *
 *  @param velocity Velocity list.
 *  @param count    count of velocity list.
 *
 *  @return An array of hues mapping each velocity.
 */
-(void) velocity:(float*)velocity ToHue:(float**)_hue count:(int)count{
    *_hue = malloc(sizeof(float)*count);
    for (int i=0;i<count;i++){
        float curVelo = velocity[i];
        curVelo = ((curVelo < V_MIN) ? V_MIN : (curVelo  > V_MAX) ? V_MAX : curVelo);
        (*_hue)[i] = H_MIN + ((curVelo-V_MIN)*(H_MAX-H_MIN))/(V_MAX-V_MIN);
    }
}
-(void) createPath{
    CGMutablePathRef path = CGPathCreateMutable();
    BOOL pathIsEmpty = YES;
    for (int i=0;i< polyline.pointCount;i++){
        CGPoint point = [self pointForMapPoint:polyline.points[i]];
        if (pathIsEmpty){
            CGPathMoveToPoint(path, nil, point.x, point.y);
            pathIsEmpty = NO;
        } else {
            CGPathAddLineToPoint(path, nil, point.x, point.y);
        }
    }
    
    pthread_rwlock_wrlock(&rwLock);
    self.path = path; //<—— don't forget this line.
    pthread_rwlock_unlock(&rwLock);
}


-(void) drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context{
    
    CGMutablePathRef fullPath = CGPathCreateMutable();
    BOOL pathIsEmpty = YES;
    for (int i=0;i< polyline.pointCount;i++){
        CGPoint point = [self pointForMapPoint:polyline.points[i]];
        if (pathIsEmpty){
            CGPathMoveToPoint(fullPath, nil, point.x, point.y);
            pathIsEmpty = NO;
        } else {
            CGPathAddLineToPoint(fullPath, nil, point.x, point.y);
        }
    }
    
    CGRect pointsRect = CGPathGetBoundingBox(fullPath);
    CGRect mapRectCG = [self rectForMapRect:mapRect];
    if (!CGRectIntersectsRect(pointsRect, mapRectCG))return;
    UIColor* pcolor,*ccolor;
    for (int i=0;i< polyline.pointCount;i++){
        CGMutablePathRef path = CGPathCreateMutable();
        CGPoint point = [self pointForMapPoint:polyline.points[i]];
        ccolor = [UIColor colorWithHue:hues[i] saturation:1.0f brightness:1.0f alpha:1.0f];
        if (i==0){
            CGPathMoveToPoint(path, nil, point.x, point.y);
        } else {
            CGPoint prevPoint = [self pointForMapPoint:polyline.points[i-1]];
            CGPathMoveToPoint(path, nil, prevPoint.x, prevPoint.y);
            CGPathAddLineToPoint(path, nil, point.x, point.y);
            float pc_r,pc_g,pc_b,pc_a,
            cc_r,cc_g,cc_b,cc_a;
            [pcolor getRed:&pc_r green:&pc_g blue:&pc_b alpha:&pc_a];
            [ccolor getRed:&cc_r green:&cc_g blue:&cc_b alpha:&cc_a];
            CGFloat gradientColors[8] = {pc_r,pc_g,pc_b,pc_a,
                                        cc_r,cc_g,cc_b,cc_a};
            
            CGFloat gradientLocation[2] = {0,1};
            CGContextSaveGState(context);
            CGFloat lineWidth = CGContextConvertSizeToUserSpace(context, (CGSize){self.lineWidth,self.lineWidth}).width;
            CGPathRef pathToFill = CGPathCreateCopyByStrokingPath(path, NULL, lineWidth, self.lineCap, self.lineJoin, self.miterLimit);
            CGContextAddPath(context, pathToFill);
            CGContextClip(context);
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, gradientColors, gradientLocation, 2);
            CGColorSpaceRelease(colorSpace);
            CGPoint gradientStart = prevPoint;
            CGPoint gradientEnd = point;
            CGContextDrawLinearGradient(context, gradient, gradientStart, gradientEnd, kCGGradientDrawsAfterEndLocation);
            CGGradientRelease(gradient);
            CGContextRestoreGState(context);
        }
        pcolor = [UIColor colorWithCGColor:ccolor.CGColor];
    }

}


@end

@implementation GradientPolylineRenderer(FileInternal)

static BOOL lineIntersectsRect(MKMapPoint p0, MKMapPoint p1, MKMapRect r)
{
    double minX = MIN(p0.x, p1.x);
    double minY = MIN(p0.y, p1.y);
    double maxX = MAX(p0.x, p1.x);
    double maxY = MAX(p0.y, p1.y);
    
    MKMapRect r2 = MKMapRectMake(minX, minY, maxX - minX, maxY - minY);
    return MKMapRectIntersectsRect(r, r2);
}

#define MIN_POINT_DELTA 1.0

- (CGPathRef)newPathForPoints:(MKMapPoint *)points
                   pointCount:(NSUInteger)pointCount
                     clipRect:(MKMapRect)mapRect
                    zoomScale:(MKZoomScale)zoomScale
                    value:(CGFloat *)v
{
    // The fastest way to draw a path in an MKOverlayView is to simplify the
    // geometry for the screen by eliding points that are too close together
    // and to omit any line segments that do not intersect the clipping rect.
    // While it is possible to just add all the points and let CoreGraphics
    // handle clipping and flatness, it is much faster to do it yourself:
    //
    if (pointCount < 2)
        return NULL;
    
    CGMutablePathRef path = NULL;
    
    BOOL needsMove = YES;
    
#define POW2(a) ((a) * (a))
    
    // Calculate the minimum distance between any two points by figuring out
    // how many map points correspond to MIN_POINT_DELTA of screen points
    // at the current zoomScale.
    double minPointDelta = MIN_POINT_DELTA / zoomScale;
    double c2 = POW2(minPointDelta);
    
    MKMapPoint point, lastPoint = points[0];
    NSUInteger i;
    for (i = 1; i < pointCount - 1; i++)
    {
        point = points[i];
        double a2b2 = POW2(point.x - lastPoint.x) + POW2(point.y - lastPoint.y);
        if (a2b2 >= c2) {
            if (lineIntersectsRect(point, lastPoint, mapRect))
            {
                if (!path)
                    path = CGPathCreateMutable();
                if (needsMove)
                {
                    CGPoint lastCGPoint = [self pointForMapPoint:lastPoint];
                    CGPathMoveToPoint(path, NULL, lastCGPoint.x, lastCGPoint.y);
                    needsMove = NO;
                }

                CGPoint cgPoint = [self pointForMapPoint:point];
                CGPathAddLineToPoint(path, NULL, cgPoint.x, cgPoint.y);
                for (int  j=1;j<pointCount;j++){
                    if (MKMapPointEqualToPoint(point, points[j])){
                        pthread_rwlock_wrlock(&rwLock);
                        *v = hues[j];
                        pthread_rwlock_unlock(&rwLock);
                        break;
                    }
                }
            }
            else
            {
                // discontinuity, lift the pen
                needsMove = YES;
            }
            lastPoint = point;
        }
    }
    
#undef POW2
    
    // If the last line segment intersects the mapRect at all, add it unconditionally
    point = points[pointCount - 1];
    if (lineIntersectsRect(lastPoint, point, mapRect))
    {
        if (!path)
            path = CGPathCreateMutable();
        if (needsMove)
        {
            CGPoint lastCGPoint = [self pointForMapPoint:lastPoint];
            CGPathMoveToPoint(path, NULL, lastCGPoint.x, lastCGPoint.y);
        }
        CGPoint cgPoint = [self pointForMapPoint:point];
        CGPathAddLineToPoint(path, NULL, cgPoint.x, cgPoint.y);
        pthread_rwlock_wrlock(&rwLock);
        *v = hues[3];
         pthread_rwlock_unlock(&rwLock);
    }
    
    return path;
}

@end
