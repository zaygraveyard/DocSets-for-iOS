//
// NSString+RelativePath.h
// Source: https://github.com/sazameki/NSString-Relative-Path-Support
//
// << License >>
//
// NSString relative path support is made by Satoshi Numata, Ph.D. This support is provided in the public domain, so you can use it in any way.



#import <Foundation/Foundation.h>


@interface NSString (RelativePath)

- (NSString *)absolutePathFromBaseDirPath:(NSString *)baseDirPath;
- (NSString *)relativePathFromBaseDirPath:(NSString *)baseDirPath;

@end


