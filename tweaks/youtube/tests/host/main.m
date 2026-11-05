#import <Foundation/Foundation.h>

NSInteger AlbrhiTestsPassed = 0;
NSInteger AlbrhiTestsFailed = 0;

void Test_Transport(void);
void Test_Direct(void);
void Test_PlayerMath(void);
void Test_Arbiter(void);
void Test_Subtitles(void);
void Test_Mux(void);
void Test_Recipe(void);
void Test_Playlist(void);
void Test_Robust(void);

int main(void) {
    @autoreleasepool {
        Test_Transport();
        Test_Direct();
        Test_PlayerMath();
        Test_Arbiter();
        Test_Subtitles();
        Test_Mux();
        Test_Recipe();
        Test_Playlist();
        Test_Robust();
        printf("\n%ld passed, %ld failed\n", (long)AlbrhiTestsPassed, (long)AlbrhiTestsFailed);
        return AlbrhiTestsFailed == 0 ? 0 : 1;
    }
}
