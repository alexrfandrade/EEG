import os # file/folder operations (creating directories)
import random # randomize stimulus order
import pandas as pd # save results to a spreadsheet
from datetime import datetime
from PIL import Image # load/manipulate images
from psychopy import visual, event, core # display stimuli, capture keypresses, timing
from psychopy.hardware import brainproducts
import serial # communicate with hardware (EEG)

# === Global experiment parameters ===
nStandard = 216
nOddball = 24
stimDuration = 0.5  # seconds
stimSize = (600, 600) # pixels
responseKey = 'o' # subject presses 'o' to respond

# === Folder paths ===
imagesFolder = 'images'
resultsFolder = 'results'
os.makedirs(resultsFolder, exist_ok=True) # if the results/ folder already exists it won't crash

# === Global results list ===
results = [] # create an empty list

# === Check for ESC key to quit the experiment ===
def check_for_exit(keys):
    if 'escape' in keys: # if ESC is in the list of keys pressed
        raise KeyboardInterrupt

# === Show instruction on the screen ===
def show_instructions(win,instructions):
    # write the text on the PsychoPy window (win)
    inst = visual.TextStim(
        win,
        text=instructions,
        color='white',
        height=30,
        wrapWidth=1500
    )
    inst.draw() # put the text in a hidden canvas (buffer), doesn't actually display it
    win.flip() # show on the screen the prepared hidden buffer

    # Clean wait for ENTER
    while True:
        keys = event.waitKeys() # waits until the subject presses a button
        check_for_exit(keys) # if the subject doesn't press ESC
        if 'return' in keys: # the loop ends if the participant presses ENTER
            break

# === Load oddball image ===
def load_single_image(win, folder):
    for f in os.listdir(folder): # scan all files in the folder
        if f.endswith("oddball.jpg"): # load the file with the suffix matching the block number
            img_path = os.path.join(folder, f) # creates a path for the image f in the folder
            pil_img = Image.open(img_path).convert('RGB') # open the image and ensure consistent color format
            # wrap it in a PsychoPy object centered at (0,0) at the global set size 'stimSize'
            return  visual.ImageStim(win, image=pil_img, size=stimSize, pos=(0, 0))
    # chrash if no matching image exists
    raise FileNotFoundError("No image ending in oddball.jpg found in {folder}")

# === Save results to CSV file ===
def save_results(results, suffix="final"): # save the trial-by-trial data (default value for suffix is "final")
    df = pd.DataFrame(results) # create a table (DataFrame) from the data in results
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S') # timestamped CSV
    filename = f'results_oddball_{suffix}_{timestamp}.csv'
    filepath = os.path.join(resultsFolder, filename)
    df.to_csv(filepath, index=False) # save the DataFrame to a CSV, without the column with row numbers
    print(f"Results saved to: {filepath}")


# === Main experiment loop ===
def run_experiment(n_blocks=1):
    global results # beacuse the variable results will be modified

    # Show instruction screen and wait for ENTER
    inst_1 = ("Please relax your muscles and try to refrain from moving and blinking too much.\n\n"
              "Press ENTER to continue.")
    show_instructions(win, inst_1)
    inst_2 = ("Instructions:\n\n"
              f"There will be {n_blocks} trials (blocks) and you will be able to take a small break between each.\n"
              "You will be shown a sequence of quickly changing images.\n"
              "Look at the center of the screen and try not to move your eyes.\n"
              "Press 'o' when you see a image with face.\n\n"
              "Press ENTER to continue.")
    show_instructions(win, inst_2)
    
    # Network connection to BrainVision Recorder
##    rcs = brainproducts.RemoteControlServer()

    # Start the global clock (after first ENTER, before Block 1)
    globalClock = core.Clock()

    for block_num in range(1, n_blocks + 1):
        print(f"\n--- Starting block {block_num} ---")

        # Load standard images for this block
        std_block_folder = os.path.join(imagesFolder, "standards") # build folder path
        std_images = []
        for f in sorted(os.listdir(std_block_folder)): # os.listdir() gets all filenames in the folder
            if f.lower().endswith(('.png', '.jpg', '.jpeg')):
                img_path = os.path.join(std_block_folder, f) # build full image path
                pil_img = Image.open(img_path).convert('RGB')
                stim = visual.ImageStim(win, image=pil_img, size=stimSize, pos=(0, 0)) # create PsychoPy stimulus
                std_images.append(stim)
        if len(std_images) != nStandard:
            raise ValueError(f"Expected {nStandard} standard images in {std_block_folder}, found {len(std_images)}.")

        random.shuffle(std_images) # randomize the order of the standard images
        oddStim = load_single_image(win, imagesFolder) # single oddball image
        
        # Block start screen and wait for ENTER
        blockText = (f"Block {block_num} / {n_blocks}\n\nPress ENTER to start.")
        show_instructions(win, blockText)
        core.wait(1)

        # Build randomized trial sequence
        trialSequence = [True] * nOddball + [False] * nStandard # False = standard trial, True = oddball trial
        random.shuffle(trialSequence)
        std_index = 0

        for trial_num, isOddball in enumerate(trialSequence, 1):
            # enumerate allows to loop trough trialSequence with an index (starting from 1 instead of 0)
            # each loop unpacks the tuple (trial_num, isOddball)

            stim = oddStim if isOddball else std_images[std_index]
            if not isOddball:
                std_index += 1

            stim.draw() # draw the stimulus in the back buffer
            win.flip() # show the stimulus
            tTarget = globalClock.getTime() # record the time of the simulus

            # Stimulus trigger
##            if isOddball:
##                rcs.sendAnnotation('Stimulus','1') # oddball=1
##            else:
##                rcs.sendAnnotation('Stimulus','2') # standard=2

            # Wait for response
            responded, RT = False, None # no value for the reaction time yet
            timer = core.Clock()
            while timer.getTime() < stimDuration: # show the image for 0.5 seconds
                if 'escape' in event.getKeys():
                    raise KeyboardInterrupt
                keys = event.getKeys(timeStamped=globalClock)
                # returns a list of tuples keys with the key pressed and the time from globalClock
                for key, keyTime in keys:
                    if key == responseKey:
                        RT = keyTime - tTarget
                        responded = True
            # win.flip() # restores to background color

            # Save each trial's data to the global results list (one dictionary per trial)
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
            pauseText = (f"End of block {block_num}.\n\n"
                "If needed, take a break for few seconds before continuing.\n"
                "Press ENTER to continue.")

    # End of experiment screen
    visual.TextStim(win, text='End of the experiment! Thank you :)\n\nPress ENTER to quit.',
                    color='white', height=30, wrapWidth=1500).draw()
    win.flip()
    while True:
        keys = event.getKeys()
        if 'return' in keys:
            break
    
    win.close()
    return results

# === Main execution ===
if __name__ == "__main__":
    try: # run this first but, if there's an error, Python jumps out and looks for a matching except
        #win = visual.Window(color=(0, 0, 0), units='pix')
        win = visual.Window(fullscr=True, color=(0, 0, 0), units='pix') # full screen window
        results = run_experiment(n_blocks=2)
    except KeyboardInterrupt: # handles specific error
        print("\nExperiment interrupted by user.")
        # Always save results if available
        if results:
            save_results(results, suffix="interrupted")
    except Exception as e: # any other error
        print(f"An error occurred: {e}") # print the error message e
        # Always save results if available
        if results:
            save_results(results, suffix="interrupted")
    finally: # always run (even if en error was caught)
        win.close()

