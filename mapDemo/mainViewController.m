//
//  mainViewController.m
//  mapDemo
//
//  Created by bravo on 13-11-21.
//  Copyright (c) 2013年 bravo. All rights reserved.
//

#import "mainViewController.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "GradientPolylineRenderer.h"
#import "GradientPolylineOverlay.h"

@interface mainViewController ()<MKMapViewDelegate,CLLocationManagerDelegate>{
    MKMapView* mapView;
    CLLocationManager *locationManager;
}

@end

@implementation mainViewController{
    GradientPolylineOverlay* polyline;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    mapView.delegate = self;
    [self.view addSubview:mapView];
}

#pragma mark - mk delegate
-(MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay{
    GradientPolylineRenderer *polylineRenderer = [[GradientPolylineRenderer alloc] initWithOverlay:overlay];
    polylineRenderer.lineWidth = 8.0f;
    return polylineRenderer;
}

#pragma mark - setup overlay

-(void) drawPolyLineFromFile:(NSString*)fileName{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", documentsDirectory, fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        FILE *file = fopen([filePath UTF8String], "r");
        char buffer[256];
    #define MAX_POINTS 3000
        int pointCount = 0;
        int pointsMount = MAX_POINTS;
        
        CLLocationCoordinate2D *points;
        float *velocity;
        points = malloc(sizeof(CLLocationCoordinate2D)*MAX_POINTS);
        velocity = malloc(sizeof(float)*MAX_POINTS);
        
        while (fgets(buffer, 256, file) != NULL){
            NSString* result = [NSString stringWithUTF8String:buffer];
            //strip off the newline
            result = [result stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            //0:latitude, 1:longitude, 2:velocity
            NSArray* elements = [result componentsSeparatedByString:@","];
            CLLocationCoordinate2D point = CLLocationCoordinate2DMake([elements[0] doubleValue], [elements[1] doubleValue]);
            if (pointCount > pointsMount){
                //magic number here, needs improvement.
                points = realloc(points, 500);
                pointsMount += 500;
            }
            velocity[pointCount] = [elements[2] floatValue];
            points[pointCount++] = point;
        }
    #undef MAX_POINTS
        polyline = [[GradientPolylineOverlay alloc] initWithPoints:points velocity:velocity count:pointCount];
        [mapView addOverlay:polyline];
    }
}

-(void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [mapView removeOverlay:polyline];
    [self drawPolyLineFromFile:@"record.txt"];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

@end
