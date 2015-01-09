/*****************************************************************************
 *   ViewController.m
 ******************************************************************************
 *   by Kirill Kornyakov and Alexander Shishkov, 5th May 2013
 ******************************************************************************
 *   Chapter 5 of the "OpenCV for iOS" book
 *
 *   Printing Postcard demonstrates how a simple photo effect
 *   can be implemented.
 *
 *   Copyright Packt Publishing 2013.
 *   http://bit.ly/OpenCV_for_iOS_book
 *****************************************************************************/

#import "ViewController.h"
#import "PostcardPrinter.hpp"
#import "opencv2/highgui/ios.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize imageView;

// 多通道彩色图片的直方图比对
-(double)CompareHist:(IplImage*)image1 withParam2:(IplImage*)image2
{
    int hist_size = 256;
    float range[] = {0,255};
    
    IplImage *gray_plane = cvCreateImage(cvGetSize(image1), 8, 1);
    cvCvtColor(image1, gray_plane, CV_BGR2GRAY);
    CvHistogram *gray_hist = cvCreateHist(1, &hist_size, CV_HIST_ARRAY);
    cvCalcHist(&gray_plane, gray_hist);
    
    IplImage *gray_plane2 = cvCreateImage(cvGetSize(image2), 8, 1);
    cvCvtColor(image2, gray_plane2, CV_BGR2GRAY);
    CvHistogram *gray_hist2 = cvCreateHist(1, &hist_size, CV_HIST_ARRAY);
    cvCalcHist(&gray_plane2, gray_hist2);
    
    return cvCompareHist(gray_hist, gray_hist2, CV_COMP_BHATTACHARYYA);
}


// 单通道彩色图片的直方图
-(double)CompareHistSignle:(IplImage*)image1 withParam2:(IplImage*)image2
{
    int hist_size = 256;
    float range[] = {0,255};
    
    CvHistogram *gray_hist = cvCreateHist(1, &hist_size, CV_HIST_ARRAY);
    cvCalcHist(&image1, gray_hist);
    
    
    CvHistogram *gray_hist2 = cvCreateHist(1, &hist_size, CV_HIST_ARRAY);
    cvCalcHist(&image2, gray_hist2);
    
    return cvCompareHist(gray_hist, gray_hist2, CV_COMP_BHATTACHARYYA);
}



// 进行肤色检测
-(void)SkinDetect:(IplImage*)src withParam:(IplImage*)dst
{
    // 创建图像头
    IplImage* hsv = cvCreateImage(cvGetSize(src), IPL_DEPTH_8U, 3);//用于存图像的一个中间变量，是用来分通道用的，分成hsv通道
    IplImage* tmpH1 = cvCreateImage( cvGetSize(src), IPL_DEPTH_8U, 1);//通道的中间变量，用于肤色检测的中间变量
    IplImage* tmpS1 = cvCreateImage(cvGetSize(src), IPL_DEPTH_8U, 1);
    IplImage* tmpH2 = cvCreateImage(cvGetSize(src), IPL_DEPTH_8U, 1);
    IplImage* tmpS2 = cvCreateImage(cvGetSize(src), IPL_DEPTH_8U, 1);
    IplImage* tmpH3 = cvCreateImage(cvGetSize(src), IPL_DEPTH_8U, 1);
    IplImage* tmpS3 = cvCreateImage(cvGetSize(src), IPL_DEPTH_8U, 1);
    IplImage* H = cvCreateImage( cvGetSize(src), IPL_DEPTH_8U, 1);
    IplImage* S = cvCreateImage( cvGetSize(src), IPL_DEPTH_8U, 1);
    IplImage* V = cvCreateImage( cvGetSize(src), IPL_DEPTH_8U, 1);
    IplImage* src_tmp1=cvCreateImage(cvGetSize(src),8,3);
    
    // 高斯模糊
    cvSmooth(src,src_tmp1,CV_GAUSSIAN,3,3); //高斯模糊
    
    // hue色度，saturation饱和度，value纯度
    cvCvtColor(src_tmp1, hsv, CV_BGR2HSV );//颜色转换
    cvSplit(hsv,H,S,V,0);//分为3个通道
    /*********************肤色检测部分**************/
    cvInRangeS(H,cvScalar(0.0,0.0,0,0),cvScalar(20.0,0.0,0,0),tmpH1);
    cvInRangeS(S,cvScalar(75.0,0.0,0,0),cvScalar(200.0,0.0,0,0),tmpS1);
    cvAnd(tmpH1,tmpS1,tmpH1,0);
    
    // Red Hue with Low Saturation
    // Hue 0 to 26 degree and Sat 20 to 90
    cvInRangeS(H,cvScalar(0.0,0.0,0,0),cvScalar(13.0,0.0,0,0),tmpH2);
    cvInRangeS(S,cvScalar(20.0,0.0,0,0),cvScalar(90.0,0.0,0,0),tmpS2);
    cvAnd(tmpH2,tmpS2,tmpH2,0);
    
    // Red Hue to Pink with Low Saturation
    // Hue 340 to 360 degree and Sat 15 to 90
    cvInRangeS(H,cvScalar(170.0,0.0,0,0),cvScalar(180.0,0.0,0,0),tmpH3);
    cvInRangeS(S,cvScalar(15.0,0.0,0,0),cvScalar(90.,0.0,0,0),tmpS3);
    cvAnd(tmpH3,tmpS3,tmpH3,0);
    
    // Combine the Hue and Sat detections
    cvOr(tmpH3,tmpH2,tmpH2,0);
    cvOr(tmpH1,tmpH2,tmpH1,0);
    
    cvCopy(tmpH1,dst);
    
    cvReleaseImage(&hsv);
    cvReleaseImage(&tmpH1);
    cvReleaseImage(&tmpS1);
    cvReleaseImage(&tmpH2);
    cvReleaseImage(&tmpS2);
    cvReleaseImage(&tmpH3);
    cvReleaseImage(&tmpS3);
    cvReleaseImage(&H);
    cvReleaseImage(&S);
    cvReleaseImage(&V);
    cvReleaseImage(&src_tmp1);
}

//图片匹配
-(BOOL)ComparePPKImage:(IplImage*)mIplImage withAnotherImage:(IplImage*)mIplImage1 withTempleImage:(IplImage*)mTempleImage
{
    //第一次模板标记
    CvPoint minLoc =[self CompareTempleImage:mTempleImage withImage:mIplImage];
    if (minLoc.x==mIplImage->width || minLoc.y==mIplImage->height) {
        printf("第一个图片的模板标记失败\n");
        return false;
    }
    //第二次模板标记
    CvPoint minLoc1 =[self CompareTempleImage:mTempleImage withImage:mIplImage1];
    if (minLoc1.x==mIplImage1->width || minLoc1.y==mIplImage1->height) {
        printf("第二个图片的模板标记失败\n");
        return false;
    }
    //裁切图片
    IplImage *cropImage,*cropImage1;
    cropImage =[self cropIplImage:mIplImage withStartPoint:minLoc withWidth:mTempleImage->width withHeight:mTempleImage->height];
    cropImage1=[self cropIplImage:mIplImage1 withStartPoint:minLoc1 withWidth:mTempleImage->width withHeight:mTempleImage->height];
    double rst = [self CompareHist:cropImage withParam2:cropImage1];
    if (rst<0.05) {
        return true;
    }
    else
    {
        return false;
    }
}

/// 基于模板图片的标记识别
-(CvPoint)CompareTempleImage:(IplImage*)templeIpl withImage:(IplImage*)mIplImage
{
    IplImage *src = mIplImage;
    IplImage *templat = templeIpl;
    IplImage *result;
    int srcW, srcH, templatW, templatH, resultH, resultW;
    srcW = src->width;
    srcH = src->height;
    templatW = templat->width;
    templatH = templat->height;
    resultW = srcW - templatW + 1;
    resultH = srcH - templatH + 1;
    result = cvCreateImage(cvSize(resultW, resultH), 32, 1);
    cvMatchTemplate(src, templat, result, CV_TM_SQDIFF);
    double minValue, maxValue;
    CvPoint minLoc, maxLoc;
    cvMinMaxLoc(result, &minValue, &maxValue, &minLoc, &maxLoc);
    if (minLoc.y+templatH>srcH || minLoc.x+templatW>srcW) {
        printf("未找到标记图片\n");
        minLoc.x=srcW;
        minLoc.y=srcH;
    }
    return minLoc;
}


-(IplImage*)cropIplImage:(IplImage*)srcIpl withStartPoint:(CvPoint)mPoint withWidth:(int)width withHeight:(int)height
{
    //裁剪后的图片
    IplImage *cropImage;
    cvSetImageROI(srcIpl, cvRect(mPoint.x, mPoint.y, width, height));
    cropImage = cvCreateImage(cvGetSize(srcIpl), IPL_DEPTH_8U, 3);
    cvCopy(srcIpl, cropImage);
    cvResetImageROI(srcIpl);
    return cropImage;
}

/// UIImage类型转换为IPlImage类型
-(IplImage*)convertToIplImage:(UIImage*)image
{
    CGImageRef imageRef = image.CGImage;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    IplImage *iplImage = cvCreateImage(cvSize(image.size.width, image.size.height), IPL_DEPTH_8U, 4);
    CGContextRef contextRef = CGBitmapContextCreate(iplImage->imageData, iplImage->width, iplImage->height, iplImage->depth, iplImage->widthStep, colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    IplImage *ret = cvCreateImage(cvGetSize(iplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplImage, ret, CV_RGB2BGR);
    cvReleaseImage(&iplImage);
    return ret;
}

/// IplImage类型转换为UIImage类型
-(UIImage*)convertToUIImage:(IplImage*)image
{
    cvCvtColor(image, image, CV_BGR2RGB);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(image->width, image->height, image->depth, image->depth * image->nChannels, image->widthStep, colorSpace, kCGImageAlphaNone | kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *ret = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return ret;
}


- (void)checkSimilarity {
    IplImage *i1, *i2;
    
    UIImage* image1 = [UIImage imageNamed:@"IMG_0150.jpg"];
    i1 = [self convertToIplImage:image1];
    UIImage* image2 = [UIImage imageNamed:@"IMG_0151.jpg"];
    i2 = [self convertToIplImage:image2];

    double res = [self CompareHist:i1 withParam2:i2];
    NSLog(@"res is %f", res);
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self checkSimilarity];
}

- (NSInteger)supportedInterfaceOrientations
{
    // Only portrait orientation
    return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    PostcardPrinter::Parameters params;
    
    // Load image with face
    UIImage* image = [UIImage imageNamed:@"lena.jpg"];
    UIImageToMat(image, params.face);
    
    // Load image with texture
    image = [UIImage imageNamed:@"texture.jpg"];
    UIImageToMat(image, params.texture);
    cvtColor(params.texture, params.texture, CV_RGBA2RGB);

    // Load image with text
    image = [UIImage imageNamed:@"text.png"];
    UIImageToMat(image, params.text, true);
    
    // Create PostcardPrinter class
    PostcardPrinter postcardPrinter(params);
    
    // Print postcard, and measure printing time
    cv::Mat postcard;
    int64 timeStart = cv::getTickCount();
    postcardPrinter.print(postcard);
    int64 timeEnd = cv::getTickCount();
    float durationMs =
        1000.f * float(timeEnd - timeStart) / cv::getTickFrequency();
    NSLog(@"Printing time = %.3fms", durationMs);
    
    if (!postcard.empty())
        imageView.image = MatToUIImage(postcard);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
