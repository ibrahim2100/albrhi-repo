//
//  SCIKeychain.m
//  Albrhi for Instagram
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import "SCIKeychain.h"
#import <Security/Security.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <string.h>
#import <stdatomic.h>

///
/// **Why this exists: an Instagram that is signed again signs in, and forgets it the next time it is opened.**
///
/// Instagram keeps its session in the keychain, and asks for it by an explicit *access group* (`kSecAttrAccessGroup`). A store build holds that
/// group in its entitlements. A copy signed again by a sideloading tool holds a different one (the tool's own team, and often a changed bundle
/// id), so the keychain answers every request for the old group with `errSecMissingEntitlement` (-34018): the session is kept in memory while the
/// app runs, nothing is written or read back, and a launch from scratch finds no account.
///
/// Rocket's Instagram build does not forget (read 2026-11-25, only the part that rewrites keychain queries; nothing of it is copied and what it
/// does is described here from the disassembly): it takes the four `SecItem…` entry points over, and for a generic-password query naming a group the
/// app does not hold it puts the app's first own group in its place. This does the same, more narrowly: **the original request is always made
/// first, and only when the keychain refuses it for entitlement is it made again, in the app's own default group.** A request the keychain accepts
/// is never touched, so a store build, a jailbreak or a correctly signed copy see no difference at all.
///
/// The default group is what the keychain says it is: one throwaway item is written *without* a group, its `kSecAttrAccessGroup` read back, and the
/// item deleted. No provisioning profile is parsed, so it holds for a profile, for TrollStore's own entitlements and for anything else.
///
/// How the entry points are taken over: the app's own images import `SecItem…` through pointer tables, and those pointers are replaced
/// (symbol rebinding, the technique `fishhook` made public). Only images that live inside the app bundle are touched, never the system's.
///

enum { kAdd = 0, kCopy, kUpdate, kDelete, kKinds };
static const char *kNames[kKinds] = {"add", "copy", "update", "delete"};

static OSStatus (*sAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*sCopy)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*sUpdate)(CFDictionaryRef, CFDictionaryRef);
static OSStatus (*sDelete)(CFDictionaryRef);

static _Atomic(NSUInteger) sCalls[kKinds], sRefused[kKinds], sRetried[kKinds], sRescued[kKinds];
static _Atomic(NSUInteger) sImages, sPointers;
static NSString *sState = nil;
static NSString *sDefaultGroup = nil;
static NSString *sLastRefusedGroup = nil;
static OSStatus sProbeStatus = 0;
static NSObject *sLock = nil;

#pragma mark - The app's own group

static NSString *SCIDefaultGroup(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (!sAdd || !sDelete) return;
        NSString *account = [@"albrhi-probe-" stringByAppendingString:[NSUUID UUID].UUIDString];
        NSDictionary *add = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: @"albrhi.keychain.probe",
            (__bridge id)kSecAttrAccount: account,
            (__bridge id)kSecValueData: [NSData dataWithBytes:"1" length:1],
            (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
            (__bridge id)kSecReturnAttributes: @YES,
        };
        CFTypeRef out = NULL;
        sProbeStatus = sAdd((__bridge CFDictionaryRef)add, &out);
        if (sProbeStatus == errSecSuccess && out) {
            id group = ((__bridge NSDictionary *)out)[(__bridge id)kSecAttrAccessGroup];
            if ([group isKindOfClass:[NSString class]]) sDefaultGroup = [group copy];
            CFRelease(out);
            NSDictionary *del = @{
                (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecAttrService: @"albrhi.keychain.probe",
                (__bridge id)kSecAttrAccount: account,
            };
            sDelete((__bridge CFDictionaryRef)del);
        }
    });
    return sDefaultGroup;
}

/// A copy of `query` with the group replaced by the app's own, or NULL when there is nothing to replace (no group named, or it is already ours).
static CFDictionaryRef SCIRemapped(CFDictionaryRef query) {
    if (!query) return NULL;
    CFTypeRef group = CFDictionaryGetValue(query, kSecAttrAccessGroup);
    if (!group || CFGetTypeID(group) != CFStringGetTypeID()) return NULL;
    NSString *own = SCIDefaultGroup();
    if (!own || CFEqual(group, (__bridge CFStringRef)own)) return NULL;
    @synchronized (sLock) { sLastRefusedGroup = [(__bridge NSString *)group copy]; }
    CFMutableDictionaryRef copy = CFDictionaryCreateMutableCopy(NULL, 0, query);
    CFDictionarySetValue(copy, kSecAttrAccessGroup, (__bridge CFStringRef)own);
    return copy;
}

#pragma mark - The four replacements

static OSStatus SCIAdd(CFDictionaryRef query, CFTypeRef *result) {
    atomic_fetch_add(&sCalls[kAdd], 1);
    OSStatus status = sAdd(query, result);
    if (status != errSecMissingEntitlement) return status;
    atomic_fetch_add(&sRefused[kAdd], 1);
    CFDictionaryRef again = SCIRemapped(query);
    if (!again) return status;
    atomic_fetch_add(&sRetried[kAdd], 1);
    status = sAdd(again, result);
    CFRelease(again);
    if (status == errSecSuccess || status == errSecDuplicateItem) atomic_fetch_add(&sRescued[kAdd], 1);
    return status;
}

static OSStatus SCICopy(CFDictionaryRef query, CFTypeRef *result) {
    atomic_fetch_add(&sCalls[kCopy], 1);
    OSStatus status = sCopy(query, result);
    if (status != errSecMissingEntitlement) return status;
    atomic_fetch_add(&sRefused[kCopy], 1);
    CFDictionaryRef again = SCIRemapped(query);
    if (!again) return status;
    atomic_fetch_add(&sRetried[kCopy], 1);
    status = sCopy(again, result);
    CFRelease(again);
    if (status == errSecSuccess || status == errSecItemNotFound) atomic_fetch_add(&sRescued[kCopy], 1);
    return status;
}

static OSStatus SCIUpdate(CFDictionaryRef query, CFDictionaryRef attributes) {
    atomic_fetch_add(&sCalls[kUpdate], 1);
    OSStatus status = sUpdate(query, attributes);
    if (status != errSecMissingEntitlement) return status;
    atomic_fetch_add(&sRefused[kUpdate], 1);
    CFDictionaryRef query2 = SCIRemapped(query);
    CFDictionaryRef attributes2 = SCIRemapped(attributes);
    if (!query2 && !attributes2) return status;
    atomic_fetch_add(&sRetried[kUpdate], 1);
    status = sUpdate(query2 ?: query, attributes2 ?: attributes);
    if (query2) CFRelease(query2);
    if (attributes2) CFRelease(attributes2);
    if (status == errSecSuccess || status == errSecItemNotFound) atomic_fetch_add(&sRescued[kUpdate], 1);
    return status;
}

static OSStatus SCIDelete(CFDictionaryRef query) {
    atomic_fetch_add(&sCalls[kDelete], 1);
    OSStatus status = sDelete(query);
    if (status != errSecMissingEntitlement) return status;
    atomic_fetch_add(&sRefused[kDelete], 1);
    CFDictionaryRef again = SCIRemapped(query);
    if (!again) return status;
    atomic_fetch_add(&sRetried[kDelete], 1);
    status = sDelete(again);
    CFRelease(again);
    if (status == errSecSuccess || status == errSecItemNotFound) atomic_fetch_add(&sRescued[kDelete], 1);
    return status;
}

#pragma mark - Taking the pointers over

static const struct mach_header_64 *sOwnHeader = NULL;

static void SCIRebindSection(intptr_t slide, const struct section_64 *section, const struct nlist_64 *symbols,
                             const char *strings, const uint32_t *indirect) {
    uint32_t type = section->flags & SECTION_TYPE;
    if (type != S_LAZY_SYMBOL_POINTERS && type != S_NON_LAZY_SYMBOL_POINTERS) return;
    const uint32_t *indices = indirect + section->reserved1;
    void **bindings = (void **)((uintptr_t)slide + section->addr);
    size_t count = section->size / sizeof(void *);
    BOOL constant = strncmp(section->segname, "__DATA_CONST", 12) == 0 || strncmp(section->segname, "__AUTH_CONST", 12) == 0;

    for (size_t i = 0; i < count; i++) {
        uint32_t index = indices[i];
        if (index == INDIRECT_SYMBOL_ABS || index == INDIRECT_SYMBOL_LOCAL || index == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) continue;
        const char *name = strings + symbols[index].n_un.n_strx;
        void *replacement = NULL;
        if (strcmp(name, "_SecItemAdd") == 0) replacement = (void *)SCIAdd;
        else if (strcmp(name, "_SecItemCopyMatching") == 0) replacement = (void *)SCICopy;
        else if (strcmp(name, "_SecItemUpdate") == 0) replacement = (void *)SCIUpdate;
        else if (strcmp(name, "_SecItemDelete") == 0) replacement = (void *)SCIDelete;
        if (!replacement || bindings[i] == replacement) continue;

        void **slot = &bindings[i];
        vm_address_t page = (vm_address_t)((uintptr_t)slot & ~(uintptr_t)(vm_page_size - 1));
        if (constant && vm_protect(mach_task_self(), page, vm_page_size, 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) != KERN_SUCCESS) continue;
        *slot = replacement;
        if (constant) vm_protect(mach_task_self(), page, vm_page_size, 0, VM_PROT_READ);
        atomic_fetch_add(&sPointers, 1);
    }
}

static void SCIImageAdded(const struct mach_header *header, intptr_t slide) {
    if (!header || header->magic != MH_MAGIC_64) return;
#ifndef SCI_KEYCHAIN_TEST
    if ((const void *)header == (const void *)sOwnHeader) return;   // this library calls the keychain through the originals
#endif
    Dl_info info;
    if (!dladdr(header, &info) || !info.dli_fname) return;
    if (!strstr(info.dli_fname, ".app/")) return;   // the app's own images only: never the system's

    const struct mach_header_64 *header64 = (const struct mach_header_64 *)header;
    const struct symtab_command *symtab = NULL;
    const struct dysymtab_command *dysymtab = NULL;
    const struct segment_command_64 *linkedit = NULL;
    const struct load_command *command = (const struct load_command *)(header64 + 1);
    for (uint32_t i = 0; i < header64->ncmds; i++, command = (const struct load_command *)((const char *)command + command->cmdsize)) {
        if (command->cmd == LC_SYMTAB) symtab = (const struct symtab_command *)command;
        else if (command->cmd == LC_DYSYMTAB) dysymtab = (const struct dysymtab_command *)command;
        else if (command->cmd == LC_SEGMENT_64 && strcmp(((const struct segment_command_64 *)command)->segname, SEG_LINKEDIT) == 0) {
            linkedit = (const struct segment_command_64 *)command;
        }
    }
    if (!symtab || !dysymtab || !linkedit || !dysymtab->nindirectsyms) return;

    uintptr_t base = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
    const struct nlist_64 *symbols = (const struct nlist_64 *)(base + symtab->symoff);
    const char *strings = (const char *)(base + symtab->stroff);
    const uint32_t *indirect = (const uint32_t *)(base + dysymtab->indirectsymoff);

    NSUInteger before = atomic_load(&sPointers);
    command = (const struct load_command *)(header64 + 1);
    for (uint32_t i = 0; i < header64->ncmds; i++, command = (const struct load_command *)((const char *)command + command->cmdsize)) {
        if (command->cmd != LC_SEGMENT_64) continue;
        const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
        if (strncmp(segment->segname, "__DATA", 6) != 0 && strncmp(segment->segname, "__AUTH", 6) != 0) continue;
        const struct section_64 *section = (const struct section_64 *)(segment + 1);
        for (uint32_t s = 0; s < segment->nsects; s++) SCIRebindSection(slide, &section[s], symbols, strings, indirect);
    }
    if (atomic_load(&sPointers) != before) atomic_fetch_add(&sImages, 1);
}

void SCIKeychainInstall(void) {
    if (sState) return;
    sLock = [[NSObject alloc] init];
    sAdd = dlsym(RTLD_DEFAULT, "SecItemAdd");
    sCopy = dlsym(RTLD_DEFAULT, "SecItemCopyMatching");
    sUpdate = dlsym(RTLD_DEFAULT, "SecItemUpdate");
    sDelete = dlsym(RTLD_DEFAULT, "SecItemDelete");
    if (!sAdd || !sCopy || !sUpdate || !sDelete) {
        sState = @"skipped: a SecItem entry point was not found";
        return;
    }
    Dl_info own;
    if (dladdr((const void *)SCIKeychainInstall, &own)) sOwnHeader = (const struct mach_header_64 *)own.dli_fbase;
    _dyld_register_func_for_add_image(SCIImageAdded);   // calls back for every image already loaded, then for each one loaded later
    sState = @"installed: every SecItem pointer in the app's own images, asked again in the app's group only when refused for entitlement (-34018)";
}

NSArray<NSString *> *SCIKeychainReportLines(void) {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:sState ?: @"not installed (a jailbreak package: the app is signed the way the store signed it)"];
    if (!sLock) return lines;
    [lines addObject:[NSString stringWithFormat:@"images patched %lu, pointers taken over %lu",
                      (unsigned long)atomic_load(&sImages), (unsigned long)atomic_load(&sPointers)]];
    for (int k = 0; k < kKinds; k++) {
        [lines addObject:[NSString stringWithFormat:@"%s: requests %lu, refused for entitlement %lu, asked again %lu, worked on the second ask %lu",
                          kNames[k], (unsigned long)atomic_load(&sCalls[k]), (unsigned long)atomic_load(&sRefused[k]),
                          (unsigned long)atomic_load(&sRetried[k]), (unsigned long)atomic_load(&sRescued[k])]];
    }
    NSString *own = sDefaultGroup, *last;
    @synchronized (sLock) { last = sLastRefusedGroup; }
    [lines addObject:[NSString stringWithFormat:@"the app's own group: %@%@", own ?: @"(not asked for yet: nothing was refused)",
                      sProbeStatus ? [NSString stringWithFormat:@" (probe status %d)", (int)sProbeStatus] : @""]];
    if (last) [lines addObject:[@"the last group the keychain refused: " stringByAppendingString:last]];
    return lines;
}
