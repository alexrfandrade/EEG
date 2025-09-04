import os
import random
import pandas as pd
from datetime import datetime
from PIL import Image
from psychopy import visual, event, core
import serial
import time  # For sleep

# === Global experiment parameters ===
nStandard = 108
nOddball = 27
stimDuration = 0.5  # seconds
ISI = 0.5  # inter-stimulus interval
stimSize = (600, 600)
responseKey = 'o'

# === Folder paths ===
oddFolder = 'oddballs'
stdFolder = 'standards'
resultsFolder = 'results'
os.makedirs(resultsFolder, exist_ok=True)

# === Global results list ===
results = []

# === Check for ESC key to quit the experiment ===
def check_for_exit():
    if 'escape' in event.getKeys():
        raise KeyboardInterrupt

# === Show instruction screen ===
def show_instructions(win):
    instructions = visual.TextStim(
        win,
        text="Press 'o' when you see a clear face.\n\nPress ENTER to continue.",
        color='white',
        height=30,
        wrapWidth=1000
    )
    instructions.draw()
    win.flip()

    # Clean wait for ENTER
    while True:
        check_for_exit()
        keys = event.waitKeys()
        if 'return' in keys:
            core.wait(0.1)
            break

# === Load oddball image for a given block ===
def load_single_image(win, folder, block_num):
    target_suffix = f"{block_num}.png"
    for f in os.listdir(folder):
        if f.endswith(target_suffix):
            img_path = os.path.join(folder, f)
            pil_img = Image.open(img_path).convert('RGB')
            return visual.ImageStim(win, image=pil_img, size=stimSize, pos=(0, 0))
    raise FileNotFoundError(f"No image ending in {target_suffix} found in {folder}")

# === Save results to CSV file ===
def save_results(results, suffix="final"):
    df = pd.DataFrame(results)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'results_oddball_{suffix}_{timestamp}.csv'
    filepath = os.path.join(resultsFolder, filename)
    df.to_csv(filepath, index=False)
    print(f"Results saved to: {filepath}")

    # Show oddball stats
    n_oddballs = sum(r['is_oddball'] for r in results)
    total_trials = len(results)
    ratio = n_oddballs / total_trials * 100 if total_trials > 0 else 0
    print(f'Oddball ratio: {ratio:.2f}% ({n_oddballs}/{total_trials} trials)')

# === Wait screen ===
def wait_screen(win):
    wait_text = visual.TextStim(
        win, 
        text="Preparing the experiment... Please wait.",
        color='white',
        height=30
    )
    wait_text.draw()
    win.flip()

# === Main experiment loop ===
def run_experiment(n_blocks=1):
    global results

    # Open full screen window
    win = visual.Window(fullscr=True, color=(0, 0, 0), units='pix')

    # Show loading screen while preparing
    wait_screen(win)
    
    # Show instruction screen and wait for ENTER
    show_instructions(win)
    core.wait(0.5)
    
    # Serial port initialization
    s = serial.Serial('COM3', baudrate=115200, bytesize=serial.EIGHTBITS,
                       parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE,
                       timeout=1)
    time.sleep(1)
    s.write(b'RR')
    time.sleep(1)
    s.write(f"{1:02X}".encode())  # Send start trigger

    # Start the global clock (after first ENTER, before Block 1)
    globalClock = core.Clock()
    fixation = visual.TextStim(win, text='+', color='white', height=40, pos=(0, 0))

    for block_num in range(1, n_blocks + 1):
        print(f"\n--- Starting block {block_num} ---")
        wait_screen(win)
        core.wait(5)

        # Load standard images for this block
        std_block_folder = os.path.join(stdFolder, f"scrambled_faces_{block_num}")
        std_images = []
        for f in sorted(os.listdir(std_block_folder)):
            if f.lower().endswith(('.png', '.jpg', '.jpeg')):
                img_path = os.path.join(std_block_folder, f)
                pil_img = Image.open(img_path).convert('RGB')
                stim = visual.ImageStim(win, image=pil_img, size=stimSize, pos=(0, 0))
                std_images.append(stim)
        if len(std_images) != nStandard:
            raise ValueError(f"Expected {nStandard} standard images in {std_block_folder}, found {len(std_images)}.")

        random.shuffle(std_images)
        oddStim = load_single_image(win, oddFolder, block_num)
        
        # Block start screen and wait for ENTER
        blockText = visual.TextStim(win, text=f"Block {block_num} / {n_blocks}\n\nPress ENTER to start.", color='white', height=30)
        blockText.draw()
        win.flip()
        while True:
            check_for_exit()
            keys = event.getKeys()
            if 'return' in keys:
                break

        # Build randomized trial sequence
        trialSequence = [True] * nOddball + [False] * nStandard
        random.shuffle(trialSequence)
        std_index = 0

        for trial_num, isOddball in enumerate(trialSequence, 1):
            check_for_exit()
            stim = oddStim if isOddball else std_images[std_index]
            if not isOddball:
                std_index += 1

            stim.draw()
            win.flip()
            tTarget = globalClock.getTime()

            # Wait for response
            responded, RT = False, None
            timer = core.Clock()
            while timer.getTime() < stimDuration:
                check_for_exit()
                keys = event.getKeys(timeStamped=globalClock)
                for key, keyTime in keys:
                    if key == responseKey:
                        RT = keyTime - tTarget
                        responded = True
            win.flip()

            # Inter-stimulus interval with fixation
            fixation.draw()
            win.flip()
            timer = core.Clock()
            while timer.getTime() < ISI:
                check_for_exit()

            results.append({
                'block': block_num,
                'trial': trial_num,
                'is_oddball': isOddball,
                'oddball_timing': tTarget,
                'response_time': RT,
                'responded': responded
            })

        # Save results after each block
        save_results(results, suffix=f'block{block_num}')

        # Inter-block pause
        if block_num < n_blocks:
            pauseText = visual.TextStim(win, text=(
                f"End of block {block_num}.\n\n"
                "Take a break if needed.\n"
                "Press ENTER to continue."
            ), color='white', height=30)
            pauseText.draw()
            win.flip()
            while True:
                check_for_exit()
                keys = event.getKeys()
                if 'return' in keys:
                    break

    # End of experiment screen
    visual.TextStim(win, text='End of the test! Thank you :)', color='white').draw()
    win.flip()
    while True:
        check_for_exit()
        keys = event.getKeys()
        if 'return' in keys:
            break
    
    # Send end trigger (commented)
    # s.write(f"{2:02X}".encode())
    # s.close()
    
    # Final message
    alertText = visual.TextStim(win, text='Results saved. Press ENTER to quit.', color='white')
    alertText.draw()
    win.flip()
    event.waitKeys(keyList=['return'])

    win.close()
    return results

# === Main execution ===
if __name__ == "__main__":
    try:
        results = run_experiment()
    except KeyboardInterrupt:
        print("\nExperiment interrupted by user.")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        # Always save results if available
        if results:
            save_results(results, suffix="interrupted")
