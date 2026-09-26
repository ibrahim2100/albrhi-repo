#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const YTMUTranslationStrategyVersion;

extern NSString *const YTMUTranslationProviderGoogle;
extern NSString *const YTMUTranslationProviderAnthropic;
extern NSString *const YTMUTranslationProviderGemini;
extern NSString *const YTMUTranslationProviderOpenAI;

extern NSString *const YTMUTranslationErrorDomain;

// The model each LLM provider uses when the user has not picked one. The
// provider, the manager's attribution label and the settings picker all
// read this so they cannot drift apart. Google Translate has no model
// and returns @"".
NSString *YTMUTranslationDefaultModelForProvider(NSString *providerName);

BOOL YTMUTranslationDebugLoggingEnabled(void);
void YTMUTranslationLogImpl(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
// Macro so argument expressions are skipped entirely when logging is off.
#define YTMUTranslationLog(...) do { if (YTMUTranslationDebugLoggingEnabled()) YTMUTranslationLogImpl(__VA_ARGS__); } while (0)

typedef NS_ENUM(NSInteger, YTMUTranslationErrorCode) {
    YTMUTranslationErrorUnknown        = 1,
    YTMUTranslationErrorNetwork        = 2,
    YTMUTranslationErrorParse          = 3,
    YTMUTranslationErrorLineCount      = 4,
    YTMUTranslationErrorMissingAPIKey  = 5,
    YTMUTranslationErrorEmptyResponse  = 6,
    YTMUTranslationErrorHTTPStatus     = 7,
};

@interface YTMUTranslationRequest : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<NSString *> *artists;
@property (nonatomic, copy) NSString *targetLanguageCode;       // e.g. "zh-Hans", "auto"
@property (nonatomic, copy) NSString *resolvedTargetLanguage;   // human-readable, e.g. "Simplified Chinese"
@property (nonatomic, copy) NSArray<NSString *> *lines;
@end

@protocol YTMULLMCompletionProvider <NSObject>
// Generic single-turn chat completion. Used by the title normalizer to ask
// the LLM for canonical song metadata. Implementors should request JSON
// output when expectJSONMode is YES (the caller will do best-effort parsing
// either way). Returns the raw assistant text on success.
- (void)completeWithSystemPrompt:(NSString *)systemPrompt
                      userPrompt:(NSString *)userPrompt
                  expectJSONMode:(BOOL)expectJSONMode
                      completion:(void(^)(NSString *_Nullable text, NSError *_Nullable error))completion;
@optional
// The same request with the reply's JSON shape given as a schema, for a provider that can enforce
// one at the API level rather than only ask for it in the prompt. Optional because a boolean "JSON
// mode" is all OpenAI and Gemini need -- and Anthropic has no schemaless JSON mode, which is why it
// used to take the flag and do nothing with it.
- (void)completeWithSystemPrompt:(NSString *)systemPrompt
                      userPrompt:(NSString *)userPrompt
                      jsonSchema:(nullable NSDictionary *)jsonSchema
                      completion:(void(^)(NSString *_Nullable text, NSError *_Nullable error))completion;
@end

// Asks for JSON the strongest way the provider supports: a schema where it takes one, JSON mode
// otherwise. Callers pass a schema and never need to know which provider is on the other end.
void YTMULLMCompleteJSON(id<YTMULLMCompletionProvider> provider,
                         NSString *systemPrompt,
                         NSString *userPrompt,
                         NSDictionary *jsonSchema,
                         void (^completion)(NSString *_Nullable text, NSError *_Nullable error));

@protocol YTMUTranslationProvider <NSObject>
- (NSString *)providerName;       // matches the YTMUTranslationProvider* constants above
- (NSString *)modelIdentifier;    // for cache keying
- (void)translateRequest:(YTMUTranslationRequest *)request
              completion:(void(^)(NSArray<NSString *> *_Nullable lines, NSError *_Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
