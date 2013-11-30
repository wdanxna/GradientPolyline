//
//  LocationViewController.m
//  mapDemo
//
//  Created by bravo on 13-11-29.
//  Copyright (c) 2013年 bravo. All rights reserved.
//

#import "LocationViewController.h"
#import <CoreLocation/CoreLocation.h>

static int MAX_LOCATIONS = 3000;

@interface LocationViewController ()<CLLocationManagerDelegate>{
    CLLocationManager *locationManager;
    CLLocationCoordinate2D *allLocations;
    float *allSpeed;
    int locationCount;
    UILabel *label;
    UILabel *signal;
}

@end

@implementation LocationViewController

-(id) init{
    self = [super init];
    if (self){
        locationManager = [[CLLocationManager alloc] init];
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        locationManager.delegate = self;
        self.view.frame = [UIScreen mainScreen].bounds;
        
        locationCount = 0;
        allLocations = malloc(sizeof(CLLocationCoordinate2D)*MAX_LOCATIONS);
        
        allSpeed = malloc(sizeof(float)*MAX_LOCATIONS);
        
        UIButton *start = [UIButton buttonWithType:UIButtonTypeSystem];
        start.frame = CGRectMake(100, 50, 100, 80);
        [start setTitle:@"start" forState:UIControlStateNormal];
        [start addTarget:self action:@selector(startAction) forControlEvents:UIControlEventTouchUpInside];
        start.tintColor =[UIColor greenColor];
        
        UIButton *stop = [UIButton buttonWithType:UIButtonTypeSystem];
        stop.frame = CGRectMake(100, 200, 100, 80);
        [stop setTitle:@"Stop" forState:UIControlStateNormal];
        [stop addTarget:self action:@selector(stopAction) forControlEvents:UIControlEventTouchUpInside];
        stop.tintColor =[UIColor greenColor];
        
        label = [[UILabel alloc] initWithFrame:CGRectMake(5, 290, 300, 50)];
        label.textColor = [UIColor greenColor];
        label.textAlignment = NSTextAlignmentCenter;
        
        signal = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 50)];
        signal.textColor = [UIColor greenColor];
        signal.textAlignment = NSTextAlignmentLeft;
        
        self.view.backgroundColor = [UIColor blackColor];
        [self.view addSubview:signal];
        [self.view addSubview:label];
        [self.view addSubview:start];
        [self.view addSubview:stop];
        

        
    }
    return self;
}

#pragma - event
-(void) startAction{
    [locationManager startUpdatingLocation];
}

-(void) stopAction{
    [locationManager stopUpdatingLocation];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [NSString stringWithFormat:@"%@/%@",documentsDirectory,@"record.txt"];
    
    NSString *text = @"";
    for (int i=0;i<locationCount;i++){
        CLLocationCoordinate2D l =[self transfrom:allLocations[i]];
        float speed = allSpeed[i];
        NSString *subStr = [NSString stringWithFormat:@"%lf,%lf,%f\n",l.latitude,l.longitude,speed];
        text = [text stringByAppendingString:subStr];
    }
    
    NSError *error;
    [text writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!error){
        label.text = @"Recorded!";
    }else {
        label.text = @"failed, file write error";
    }
    
    locationCount = 0;
}

#pragma mark - locationManager delegate
-(void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    CLLocation *location = (CLLocation*)locations.lastObject;
    if (location.horizontalAccuracy < 0)
    {
        signal.text = @"No Singal";
        signal.textColor = [UIColor redColor];
    }
    else if (location.horizontalAccuracy > 163)
    {
        signal.text = @"POOR";
        signal.textColor = [UIColor orangeColor];
    }
    else if (location.horizontalAccuracy > 48)
    {
        signal.text = @"AVERAGE";
        signal.textColor = [UIColor yellowColor];
    }
    else
    {
        signal.text = @"STRONG";
        signal.textColor = [UIColor greenColor];
    }
    CLLocationCoordinate2D currentlocation = location.coordinate;
    float currentSpeed = ((CLLocation*)locations.lastObject).speed;
    NSString *tstr = [NSString stringWithFormat:@"%f,%f,%f",currentlocation.latitude,currentlocation.longitude,currentSpeed];
    label.text = tstr;
    if (locationCount-1 > MAX_LOCATIONS ){
        allLocations = realloc(allLocations, sizeof(CLLocationCoordinate2D)*500);
        allSpeed = realloc(allSpeed, sizeof(float)*500);
        MAX_LOCATIONS+= 500;
    }
    allSpeed[locationCount] = currentSpeed;
    allLocations[locationCount++] = currentlocation;
}

#pragma mark - gps corecteness
-(CLLocationCoordinate2D) transfrom:(CLLocationCoordinate2D)oldCoord{
    static double a = 6378245.0;
    static double ee = 0.00669342162296594323;
    
    if ([self outOfChina:oldCoord]){
        return oldCoord;
    }
    double dLat = [self transformLat:oldCoord.longitude - 105.0 y:oldCoord.latitude - 35.0];
    double dLon =[self transformLon:oldCoord.longitude - 105.0 y:oldCoord.latitude - 35.0];
    double radLat = oldCoord.latitude / 180.0 * M_PI;
    
    double magic = sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = sqrt(magic);
    
    dLat = (dLat * 180.0) / ((a*(1-ee)) / (magic * sqrtMagic) * M_PI);
    dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * M_PI);
    
    return CLLocationCoordinate2DMake(oldCoord.latitude+dLat, oldCoord.longitude+dLon);
}

-(double) transformLat:(double)x y:(double)y{
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(ABS(x));
    ret += (20.0 * sin(6.0 * x * M_PI) + 20.0 * sin(2.0 * x * M_PI)) * 2.0 / 3.0;
    ret += (20.0 * sin(y * M_PI) + 40.0 * sin(y / 3.0 * M_PI)) * 2.0 / 3.0;
    ret += (160.0 * sin(y / 12.0 * M_PI) + 320 *sin(y * M_PI / 30.0)) * 2.0 / 3.0;
    return ret;
}

-(double) transformLon:(double)x y:(double)y{
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(ABS(x));
    ret += (20.0 * sin(6.0 * x * M_PI) + 20.0 * sin(2.0 * x * M_PI)) * 2.0 / 3.0;
    ret += (20.0 * sin(x * M_PI) + 40.0 * sin(x / 3.0 * M_PI)) * 2.0 / 3.0;
    ret += (150.0 * sin(x / 12.0 * M_PI) + 300.0 * sin(x / 30.0 * M_PI)) * 2.0 / 3.0;
    return ret;
}

-(BOOL) outOfChina:(CLLocationCoordinate2D)coord{
    if (coord.longitude < 72.004 || coord.longitude > 137.8347)
        return true;
    if (coord.latitude < 0.8293 || coord.latitude > 55.8271)
        return true;
    return false;
}

#pragma - mark origin



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) dealloc{
    free(allLocations);
    free(allSpeed);
}

@end
