# bitmap_encoder_decoder
Encodes and decodes text into a bitmap image. It is written in gas assembly and it's in a single file for the sake of university submission.

Functionality breakdown:
1. Adding lead and tail to the message
2. Compressing the message using the Run-Length Encoding (RLE) technique.
3. Preparing the barcode.
4. Using XOR to encrypt the message into the barcode.
5. Saving the results as image bitmaps, in BMP format.
6. (Optional) Decrypting the message from bitmap.
