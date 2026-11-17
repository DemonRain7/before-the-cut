"""Regenerate every generated asset of Before the Cut.

Run from tools/art:  python build_all.py
Then re-import in Godot:  godot --headless --path ../../game --import
"""
import gen_audio
import gen_booth
import gen_clinic
import gen_font
import gen_gore
import gen_patients
import gen_scopes
import gen_team
import gen_ui


def main():
    if hasattr(gen_font, "main"):
        gen_font.main()
    gen_clinic.main()
    gen_patients.main(None)
    gen_scopes.main(None)
    gen_ui.main()
    gen_booth.main()      # the booth round the window: it uses the pads gen_ui draws
    gen_team.main()
    gen_gore.main()
    gen_audio.main()
    print("all assets rebuilt")


if __name__ == "__main__":
    main()
