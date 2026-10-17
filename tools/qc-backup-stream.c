/* Read a block device once, hash every byte, stream bytes after a resume offset. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <openssl/evp.h>
int main(int argc, char **argv) {
    if (argc != 4) return 2;
    char *end;
    uint64_t skip = strtoull(argv[3], &end, 10);
    if (!*argv[3] || *end) return 2;
    FILE *input = fopen(argv[1], "rb");
    if (!input) return 3;
    unsigned char *buffer = malloc(4 * 1024 * 1024);
    EVP_MD_CTX *context = EVP_MD_CTX_new();
    if (!buffer || !context || !EVP_DigestInit_ex(context, EVP_sha256(), NULL)) return 4;
    size_t count;
    while ((count = fread(buffer, 1, 4 * 1024 * 1024, input))) {
        if (!EVP_DigestUpdate(context, buffer, count)) return 5;
        size_t start = skip < count ? (size_t)skip : count;
        skip -= start;
        if (fwrite(buffer + start, 1, count - start, stdout) != count - start) return 6;
    }
    if (ferror(input) || skip || fflush(stdout)) return 7;
    fclose(input);
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digest_size = 0;
    if (!EVP_DigestFinal_ex(context, digest, &digest_size) || digest_size != 32) return 8;
    FILE *output = fopen(argv[2], "w");
    if (!output) return 9;
    for (size_t index = 0; index < digest_size; ++index)
        if (fprintf(output, "%02x", digest[index]) != 2) return 10;
    if (fputc('\n', output) == EOF || fclose(output)) return 11;
    free(buffer);
    EVP_MD_CTX_free(context);
    return 0;
}
