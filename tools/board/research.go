package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// GitHub rejects comment bodies over 65,536 characters.
const maxCommentChars = 60000

func researchMarker(n int) string { return fmt.Sprintf("<!-- board-research:%d -->", n) }

func researchBody(n int, dir string) (string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "", err
	}
	var names []string
	for _, e := range entries {
		if !e.IsDir() && !strings.HasPrefix(e.Name(), ".") && strings.HasSuffix(e.Name(), ".md") {
			names = append(names, e.Name())
		}
	}
	// summary.md first so a truncated sync still leads with the conclusion.
	sort.Slice(names, func(a, b int) bool {
		if (names[a] == "summary.md") != (names[b] == "summary.md") {
			return names[a] == "summary.md"
		}
		return names[a] < names[b]
	})
	head := fmt.Sprintf("%s\n> 自動同期した調査結果の写し。正本はローカルの `%s/` にあり、ここを編集しても次の同期で上書きされる。\n\n", researchMarker(n), dir)
	var full strings.Builder
	full.WriteString(head)
	for _, name := range names {
		b, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return "", err
		}
		fmt.Fprintf(&full, "### %s\n\n%s\n\n", name, strings.TrimSpace(string(b)))
	}
	if len([]rune(full.String())) <= maxCommentChars {
		return full.String(), nil
	}
	var short strings.Builder
	short.WriteString(head)
	short.WriteString("全文が GitHub のコメントの上限を超えるため、summary.md とファイルの一覧だけを同期した。\n\n")
	if b, err := os.ReadFile(filepath.Join(dir, "summary.md")); err == nil {
		s := []rune(strings.TrimSpace(string(b)))
		if len(s) > maxCommentChars/2 {
			s = append(s[:maxCommentChars/2], []rune("\n\n…（以下略）")...)
		}
		fmt.Fprintf(&short, "### summary.md\n\n%s\n\n", string(s))
	}
	short.WriteString("### ファイル\n\n")
	for _, name := range names {
		fmt.Fprintf(&short, "- %s\n", name)
	}
	return short.String(), nil
}

// syncResearch mirrors research/<n>/*.md into one marked comment on the Issue.
// It is a no-op outside a research worker so the PostToolUse hook stays cheap.
func syncResearch(cfg Config, n int, ifOlder time.Duration) error {
	if n <= 0 {
		return nil
	}
	dir := researchDir(n)
	if st, err := os.Stat(dir); err != nil || !st.IsDir() {
		return nil
	}
	stamp := filepath.Join(dir, ".synced")
	if ifOlder > 0 {
		if st, err := os.Stat(stamp); err == nil && time.Since(st.ModTime()) < ifOlder {
			return nil
		}
	}
	body, err := researchBody(n, dir)
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp("", "board-research-*.md")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.WriteString(body); err != nil {
		tmp.Close()
		return err
	}
	tmp.Close()

	out, err := runGH(true, "api", "--paginate", fmt.Sprintf("repos/%s/issues/%d/comments", cfg.Repo, n),
		"--jq", fmt.Sprintf(`.[] | select(.body | contains(%q)) | .id`, researchMarker(n)))
	if err != nil {
		return err
	}
	ids := strings.Fields(string(out))
	if len(ids) > 0 {
		_, err = runGH(true, "api", "-X", "PATCH", fmt.Sprintf("repos/%s/issues/comments/%s", cfg.Repo, ids[0]), "-F", "body=@"+tmp.Name(), "--silent")
	} else {
		_, err = runGH(true, "api", "-X", "POST", fmt.Sprintf("repos/%s/issues/%d/comments", cfg.Repo, n), "-F", "body=@"+tmp.Name(), "--silent")
	}
	if err != nil {
		return err
	}
	now := time.Now()
	if f, err := os.Create(stamp); err == nil {
		f.Close()
	}
	return os.Chtimes(stamp, now, now)
}
