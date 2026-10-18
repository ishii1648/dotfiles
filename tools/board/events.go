package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"time"
)

type Event struct {
	At    time.Time `json:"at"`
	Issue int       `json:"issue"`
	By    string    `json:"by"`
	Type  string    `json:"type"`
	Text  string    `json:"text,omitempty"`
}

var eventTypes = map[string]bool{"dispatched": true, "started": true}

const maxEventText = 500

func appendEvent(e Event) error {
	if !eventTypes[e.Type] {
		return fmt.Errorf("unknown event type %q", e.Type)
	}
	if e.Issue <= 0 {
		return fmt.Errorf("issue number must be positive")
	}
	if e.At.IsZero() {
		e.At = time.Now()
	}
	e.Text = strings.Join(strings.Fields(e.Text), " ")
	if r := []rune(e.Text); len(r) > maxEventText {
		e.Text = string(r[:maxEventText]) + "…"
	}
	b, err := json.Marshal(e)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(stateDir(), 0o755); err != nil {
		return err
	}
	f, err := os.OpenFile(eventsPath(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	// One write call per line: O_APPEND positions every write at EOF, so short
	// lines from concurrent sessions do not interleave in practice. POSIX does
	// not guarantee it for regular files, which is why readers skip bad lines.
	_, err = f.Write(append(b, '\n'))
	return err
}

func parseEventLine(line []byte) (Event, bool) {
	var e Event
	line = bytes.TrimSpace(line)
	if len(line) == 0 {
		return e, false
	}
	if err := json.Unmarshal(line, &e); err != nil || e.Issue <= 0 || !eventTypes[e.Type] {
		return e, false
	}
	return e, true
}

// tailer reads events.jsonl incrementally. A trailing line without a newline
// is held back until it is complete.
type tailer struct {
	path    string
	off     int64
	partial []byte
	bad     int
}

// read returns new events. reset is true when the file shrank (rotated or
// truncated by hand), in which case the caller must drop what it had.
func (t *tailer) read() (evs []Event, reset bool, err error) {
	f, err := os.Open(t.path)
	if os.IsNotExist(err) {
		if t.off > 0 {
			t.off, t.partial = 0, nil
			return nil, true, nil
		}
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return nil, false, err
	}
	if st.Size() < t.off {
		t.off, t.partial, reset = 0, nil, true
	}
	if st.Size() == t.off {
		return nil, reset, nil
	}
	if _, err := f.Seek(t.off, io.SeekStart); err != nil {
		return nil, reset, err
	}
	data, err := io.ReadAll(f)
	if err != nil {
		return nil, reset, err
	}
	t.off += int64(len(data))
	data = append(t.partial, data...)
	last := bytes.LastIndexByte(data, '\n')
	if last < 0 {
		t.partial = data
		return nil, reset, nil
	}
	t.partial = append([]byte(nil), data[last+1:]...)
	for _, line := range bytes.Split(data[:last], []byte{'\n'}) {
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		if e, ok := parseEventLine(line); ok {
			evs = append(evs, e)
		} else {
			t.bad++
		}
	}
	return evs, reset, nil
}

func readAllEvents() ([]Event, error) {
	t := &tailer{path: eventsPath()}
	evs, _, err := t.read()
	if err != nil {
		return nil, err
	}
	if len(t.partial) > 0 {
		if e, ok := parseEventLine(t.partial); ok {
			evs = append(evs, e)
		}
	}
	return evs, nil
}

func hasDispatched(evs []Event, n int) bool {
	for _, e := range evs {
		if e.Issue == n && e.Type == "dispatched" {
			return true
		}
	}
	return false
}

func ensureStateDir() error {
	return os.MkdirAll(stateDir(), 0o755)
}
