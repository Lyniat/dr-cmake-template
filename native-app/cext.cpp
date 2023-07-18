#include <dragonruby.h>

static drb_api_t *drb_api;

mrb_int add(mrb_int a, mrb_int b){
    return a + b;
}

DRB_FFI
#ifdef __cplusplus
extern "C" {
#endif

DRB_FFI_EXPORT
void drb_register_c_extensions_with_api(mrb_state *state, struct drb_api_t *api) {
    drb_api = api;

    struct RClass *FFI = drb_api->mrb_define_module(state, "FFI");
    struct RClass *module = drb_api->mrb_define_module_under(state, FFI, "CExt");

    drb_api->mrb_define_module_function(state, module, "add", {[](mrb_state *mrb, mrb_value self) {
        mrb_int a, b;
        drb_api->mrb_get_args(mrb, "ii", &a, &b);

        mrb_int i_result = add(a, b);
        mrb_value result = drb_api->mrb_int_value(mrb, i_result);
        return result;
    }}, MRB_ARGS_REQ(2));

#ifdef __cplusplus
}
#endif

}
