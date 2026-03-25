#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <AppKit/AppKit.h>

static CGImageRef CreateNormalizedCGImage(CGImageRef sourceImage) {
    size_t width = CGImageGetWidth(sourceImage);
    size_t height = CGImageGetHeight(sourceImage);
    if (width == 0 || height == 0) {
        return nil;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (!colorSpace) {
        return nil;
    }

    CGContextRef context = CGBitmapContextCreate(
        NULL,
        width,
        height,
        8,
        0,
        colorSpace,
        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big
    );
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        return nil;
    }

    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), sourceImage);
    CGImageRef normalizedImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return normalizedImage;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: %s <image>\n", argv[0]);
            return 2;
        }

        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
        if (!image) {
            fprintf(stderr, "failed to load image\n");
            return 1;
        }

        CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
        if (!cgImage) {
            fprintf(stderr, "failed to decode image\n");
            return 1;
        }

        CGImageRef normalizedImage = CreateNormalizedCGImage(cgImage);
        if (!normalizedImage) {
            fprintf(stderr, "failed to normalize image\n");
            return 1;
        }

        VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] init];
        request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
        request.recognitionLanguages = @[ @"zh-Hans", @"en-US" ];
        request.usesLanguageCorrection = YES;
        if (@available(macOS 13.0, *)) {
            request.revision = VNRecognizeTextRequestRevision3;
            request.automaticallyDetectsLanguage = YES;
        }

        NSError *error = nil;
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:normalizedImage options:@{}];
        [handler performRequests:@[request] error:&error];
        CGImageRelease(normalizedImage);
        if (error) {
            fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        for (VNRecognizedTextObservation *observation in request.results) {
            NSArray<VNRecognizedText *> *candidates = [observation topCandidates:3];
            for (VNRecognizedText *candidate in candidates) {
                if (candidate && candidate.string.length > 0) {
                    printf("%s\n", candidate.string.UTF8String);
                }
            }
        }
    }
    return 0;
}
