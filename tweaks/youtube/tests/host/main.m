#import <Foundation/Foundation.h>

NSInteger AlbrhiTestsPassed = 0;
NSInteger AlbrhiTestsFailed = 0;

void Test_Transport(void);
void Test_Direct(void);

int main(void) {
    @autoreleasepool {
        Test_Transport();
        Test_Direct();
        printf("\n%ld passed, %ld failed\n", (long)AlbrhiTestsPassed, (long)AlbrhiTestsFailed);
        return AlbrhiTestsFailed == 0 ? 0 : 1;
    }
}
