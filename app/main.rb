$gtk.ffi_misc.gtk_dlopen("cext")
include FFI::CExt

def tick args
    output = FFI::CExt::add(2, 3)
    args.outputs.labels << {
        x:                       100,
        y:                       100,
        text:                    output,
        size_enum:               6,
        r:                       155,
        g:                       50,
        b:                       50,
        a:                       255,
     }
end
