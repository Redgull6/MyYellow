roms := \
	pokeMyYellow.gbc \
	pokeMyYellow_debug.gbc
patches := \
	pokeMyYellow.patch

rom_obj := \
	audio.o \
	home.o \
	main.o \
	maps.o \
	ram.o \
	text.o \
	gfx/pics.o \
	gfx/pikachu.o \
	gfx/sprites.o \
	gfx/tilesets.o

pokeMyYellow_obj       := $(rom_obj)
pokeMyYellow_debug_obj := $(rom_obj:.o=_debug.o)
pokeMyYellow_vc_obj    := $(rom_obj:.o=_vc.o)


### Build tools

ifeq (,$(shell which sha1sum))
SHA1 := shasum
else
SHA1 := sha1sum
endif

RGBDS ?=
RGBASM  ?= $(RGBDS)rgbasm
RGBFIX  ?= $(RGBDS)rgbfix
RGBGFX  ?= $(RGBDS)rgbgfx
RGBLINK ?= $(RGBDS)rgblink


### Build targets

.SUFFIXES:
.SECONDEXPANSION:
.PRECIOUS:
.SECONDARY:
.PHONY: all yellow MyYellow_debug clean tidy compare tools

all: $(roms)
yellow:       pokeMyYellow.gbc
yellow_debug: pokeMyYellow_debug.gbc
yellow_vc:    pokeMyYellow.patch

clean: tidy
	find gfx \
	     \( -iname '*.1bpp' \
	        -o -iname '*.2bpp' \
	        -o -iname '*.pic' \) \
	     -delete
	find audio/pikachu_cries \
	     \( -iname '*.pcm' \) \
	     -delete

tidy:
	$(RM) $(roms) \
	      $(roms:.gbc=.sym) \
	      $(roms:.gbc=.map) \
	      $(patches) \
	      $(patches:.patch=_vc.gbc) \
	      $(patches:.patch=_vc.sym) \
	      $(patches:.patch=_vc.map) \
	      $(patches:%.patch=vc/%.constants.sym) \
	      $(pokeMyYellow_obj) \
	      $(pokeMyYellow_vc_obj) \
	      $(pokeMyYellow_debug_obj) \
	      rgbdscheck.o
	$(MAKE) clean -C tools/

compare: $(roms) $(patches)
	@$(SHA1) -c roms.sha1

tools:
	$(MAKE) -C tools/


RGBASMFLAGS = -Q8 -P includes.asm -Weverything -Wtruncation=1
# Create a sym/map for debug purposes if `make` run with `DEBUG=1`
ifeq ($(DEBUG),1)
RGBASMFLAGS += -E
endif

$(pokeMyYellow_debug_obj): RGBASMFLAGS += -D _DEBUG
$(pokeMyYellow_vc_obj):    RGBASMFLAGS += -D _YELLOW_VC

%.patch: %_vc.gbc %.gbc vc/%.patch.template
	tools/make_patch $*_vc.sym $^ $@

rgbdscheck.o: rgbdscheck.asm
	$(RGBASM) -o $@ $<

# Build tools when building the rom.
# This has to happen before the rules are processed, since that's when scan_includes is run.
ifeq (,$(filter clean tidy tools,$(MAKECMDGOALS)))

$(info $(shell $(MAKE) -C tools))

# The dep rules have to be explicit or else missing files won't be reported.
# As a side effect, they're evaluated immediately instead of when the rule is invoked.
# It doesn't look like $(shell) can be deferred so there might not be a better way.
preinclude_deps := includes.asm $(shell tools/scan_includes includes.asm)
define DEP
$1: $2 $$(shell tools/scan_includes $2) $(preinclude_deps) | rgbdscheck.o
	$$(RGBASM) $$(RGBASMFLAGS) -o $$@ $$<
endef

# Dependencies for objects
$(foreach obj, $(pokeMyYellow_obj), $(eval $(call DEP,$(obj),$(obj:.o=.asm))))
$(foreach obj, $(pokeMyYellow_debug_obj), $(eval $(call DEP,$(obj),$(obj:_debug.o=.asm))))
$(foreach obj, $(pokeMyYellow_vc_obj), $(eval $(call DEP,$(obj),$(obj:_vc.o=.asm))))

endif


%.asm: ;


pokeMyYellow_pad       = 0x00
pokeMyYellow_debug_pad = 0xff
pokeMyYellow_vc_pad    = 0x00

opts = -cjsv -k 01 -l 0x33 -m MBC5+RAM+BATTERY -p 0 -r 03 -t "POKEMON YELLOW"

%.gbc: $$(%_obj) layout.link
	$(RGBLINK) -p $($*_pad) -w -m $*.map -n $*.sym -l layout.link -o $@ $(filter %.o,$^)
	$(RGBFIX) -p $($*_pad) $(opts) $@


### Misc file-specific graphics rules

gfx/battle/move_anim_0.2bpp: tools/gfx += --trim-whitespace
gfx/battle/move_anim_1.2bpp: tools/gfx += --trim-whitespace

gfx/credits/the_end.2bpp: tools/gfx += --interleave --png=$<

gfx/slots/slots_1.2bpp: tools/gfx += --trim-whitespace

gfx/tilesets/%.2bpp: tools/gfx += --trim-whitespace
gfx/tilesets/reds_house.2bpp: tools/gfx += --preserve=0x48

gfx/title/pokemon_logo.2bpp: tools/gfx += --trim-whitespace

gfx/trade/game_boy.2bpp: tools/gfx += --remove-duplicates

gfx/sgb/border.2bpp: tools/gfx += --trim-whitespace

gfx/surfing_pikachu/surfing_pikachu_1c.2bpp: tools/gfx += --trim-whitespace
gfx/surfing_pikachu/surfing_pikachu_3.2bpp: tools/gfx += --trim-whitespace


### Catch-all graphics rules

%.png: ;

%.2bpp: %.png
	$(RGBGFX) $(rgbgfx) -o $@ $<
	$(if $(tools/gfx),\
		tools/gfx $(tools/gfx) -o $@ $@)

%.1bpp: %.png
	$(RGBGFX) $(rgbgfx) --depth 1 -o $@ $<
	$(if $(tools/gfx),\
		tools/gfx $(tools/gfx) --depth 1 -o $@ $@)

%.pic: %.2bpp
	tools/pkmncompress $< $@


### Catch-all audio rules

%.wav: ;

%.pcm: %.wav
	tools/pcm $< $@
