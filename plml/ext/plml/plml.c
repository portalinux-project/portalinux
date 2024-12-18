#include <ruby.h>
#include <plrt-plml.h>

void signalHandler(){}

static VALUE load_file(VALUE self, VALUE file){
	VALUE retHash = rb_hash_new();
	char fileLine[4096] = "";
	char* fileName = StringValueCStr(file);
	plmt_t* mt = plMTInit(32 * 1024);

	FILE* plmlFile = fopen(fileName, "r");
	if(plmlFile == NULL)
		rb_raise(rb_eRuntimeError, "Failed to open file %s", fileName);

	while(fgets(fileLine, 4096, plmlFile) != NULL){
		plmltoken_t holder = plMLParse(plRTStrFromCStr(fileLine, NULL), mt);
		VALUE key;
		VALUE value;
		if(holder.isArray)
			value = rb_ary_new();

//		printf("%s, %d, %d\n", holder.name.data.pointer, holder.name.data.size, holder.type);

		if(holder.type == PLML_TYPE_HEADER || holder.type == PLML_TYPE_NULL){
			if(holder.type == PLML_TYPE_HEADER)
				plMLFreeToken(holder);
			continue;
		}

		key = rb_utf8_str_new(holder.name.data.pointer, holder.name.data.size);
		switch(holder.type){
			case PLML_TYPE_INT:
				if(holder.isArray){
					for(int i = 0; i < holder.value.array.size; i++)
						rb_ary_push(value, LONG2NUM(((long*)holder.value.array.pointer)[i]));
				}else{
					value = LONG2NUM(holder.value.integer);
				}
				break;
			case PLML_TYPE_FLOAT:
				if(holder.isArray){
					for(int i = 0; i < holder.value.array.size; i++)
						rb_ary_push(value, DBL2NUM(((double*)holder.value.array.pointer)[i]));
				}else{
					value = DBL2NUM(holder.value.decimal);
				}
				break;
			case PLML_TYPE_BOOL:
				if(holder.isArray){
					for(int i = 0; i < holder.value.array.size; i++){
						if(((bool*)holder.value.array.pointer)[i])
							rb_ary_push(value, Qtrue);
						else
							rb_ary_push(value, Qfalse);
					}
				}else{
					if(holder.value.boolean)
						value = Qtrue;
					else
						value = Qfalse;
				}
				break;
			case PLML_TYPE_STRING:
				if(holder.isArray){
					for(int i = 0; i < holder.value.array.size; i++)
						rb_ary_push(value, rb_utf8_str_new(((plptr_t*)holder.value.array.pointer)[i].pointer, ((plptr_t*)holder.value.array.pointer)[i].size));
				}else{
					value = rb_utf8_str_new(holder.value.string.pointer, holder.value.string.size);
				}
				break;
		}

//		printf("%s, Token Parsed\n", holder.name.data.pointer);

		plMLFreeToken(holder);
		rb_hash_aset(retHash, key, value);
	}

	plMTStop(mt);
	return retHash;
}

void Init_plml(){
	VALUE plml = rb_define_module("PLML");
	rb_define_singleton_method(plml, "load_file", load_file, 1);
}
