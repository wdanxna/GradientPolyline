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
    CLLocationCoordinate2D lt;
    CLLocationCoordinate2D rt;
    CLLocationCoordinate2D rb;
    CLLocationCoordinate2D lb;
    
    MKPolygon* polygon;
    GradientPolylineOverlay* polyline;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    mapView.delegate = self;
    [self.view addSubview:mapView];
    [self setupBounds];
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(23.29043, 112.81630), 500, 500);
    [mapView setRegion:region];
    [self placeOverlay];
//    [self drawPolyLineFromFile:@"record.txt"];
}

#pragma mark - mk delegate
-(MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay{
    UIColor* purpleColor = [UIColor colorWithRed:0.149f green:0.0f blue:0.40f alpha:0.5f];
    if (overlay == polygon){
        MKPolygonRenderer *polygonRenderer = [[MKPolygonRenderer alloc] initWithOverlay:overlay];
        polygonRenderer.fillColor = purpleColor;
        return polygonRenderer;
    }else if (overlay == polyline){
        GradientPolylineRenderer *polylineRenderer = [[GradientPolylineRenderer alloc] initWithOverlay:overlay];
        polylineRenderer.lineWidth = 8.0f;
        polylineRenderer.strokeColor = [UIColor redColor];
        return polylineRenderer;
    }
    return nil;
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
            if (pointCount > MAX_POINTS){
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

-(void) placeOverlay{
    CLLocationCoordinate2D highlight[4];
    
    highlight[0] = lt;
    highlight[1] = rt;
    highlight[2] = rb;
    highlight[3] = lb;
    
    polygon = [MKPolygon polygonWithCoordinates:highlight count:4];
    [mapView addOverlay:polygon level:MKOverlayLevelAboveLabels];
}

-(void) setupBounds{
    lt = CLLocationCoordinate2DMake(23.29131,112.8155);
    rt = CLLocationCoordinate2DMake(23.29061, 112.8177);
    lb = CLLocationCoordinate2DMake(23.29014, 112.8151);
    rb = CLLocationCoordinate2DMake(23.28949, 112.8173);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

@end
