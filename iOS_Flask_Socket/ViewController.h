//
//  ViewController.h
//  iOS_Flask_Socket
//
//  Created by fly on 2020/3/15.
//  Copyright © 2020 admin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *IPTextField;
@property (weak, nonatomic) IBOutlet UITextField *PortTextField;
- (IBAction)didPressedConnect:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *lblResult;
@property (weak, nonatomic) IBOutlet UITextField *inputTextField;
- (IBAction)didPressedSend:(id)sender;


@end

