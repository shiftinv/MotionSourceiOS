#import <UIKit/UIKit.h>

#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>

@interface ViewController : UIViewController <GCDAsyncUdpSocketDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *portTextField;
@property (weak, nonatomic) IBOutlet UILabel *ipAddressLabel;
@property (weak, nonatomic) IBOutlet UIButton *startstopServerButton;
@property (weak, nonatomic) IBOutlet UISlider *updateIntervalSlider;
@property (weak, nonatomic) IBOutlet UITextField *updateIntervalTextField;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;

@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *orientationButtons;

- (void)setUpdatesPerSec:(int)ups;
- (void)startGyroUpdates;
- (void)stopGyroUpdates;
- (void)startServer;
- (void)stopServer;
- (IBAction)startstopServer;
- (IBAction)setPortPressed:(id)sender;
- (IBAction)intervalSliderChanged:(id)sender;
- (IBAction)setIntervalPressed:(id)sender;
- (IBAction)changeOrientation:(UIButton *)sender;
- (IBAction)enableAccelerometerSwitch:(UISwitch *)sender;
- (IBAction)accelerometerInfoPressed:(UIButton *)sender;
- (void)displayErrorWithMessage:(NSString *)message;
- (void)handleMotionUpdate:(CMDeviceMotion *)motionData withError:(NSError *)error;
- (NSString *)getIPAddress;

@end

