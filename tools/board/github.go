package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

type Issue struct {
	Number    int
	Title     string
	URL       string
	State     string // OPEN or CLOSED
	Body      string
	CreatedAt time.Time
	UpdatedAt time.Time
	ClosedAt  *time.Time
	Labels    []string
	Parent    int
	SubIssues []IssueRef
	BlockedBy []IssueRef
	// PRs are the open and merged pull requests that close this Issue
	// ("Closes <R>#<N>"), including ones in other repositories.
	PRs []PRRef
}

type IssueRef struct {
	Number int    `json:"number"`
	Title  string `json:"title"`
	State  string `json:"state"`
}

type PRRef struct {
	Number    int       `json:"number"`
	URL       string    `json:"url"`
	State     string    `json:"state"`
	IsDraft   bool      `json:"isDraft"`
	UpdatedAt time.Time `json:"updatedAt"`
}

func (i *Issue) Open() bool { return i.State == "OPEN" }

func (i *Issue) HasLabel(l string) bool {
	for _, x := range i.Labels {
		if x == l {
			return true
		}
	}
	return false
}

const (
	labelEpic     = "type:epic"
	labelProject  = "type:project"
	labelResearch = "research"
)

func (i *Issue) Kind() string {
	switch {
	case i.HasLabel(labelProject):
		return "project"
	case i.HasLabel(labelEpic):
		return "epic"
	}
	return "task"
}

const issueFields = `number title url state body createdAt updatedAt closedAt
labels(first: 20) { nodes { name } }
parent { number }
subIssues(first: 50) { nodes { number title state } }
blockedBy(first: 20) { nodes { number title state } }
closedByPullRequestsReferences(first: 10, includeClosedPrs: true) { nodes { number url state isDraft updatedAt } }`

// Closed issues are limited to the most recently updated ones; older closed
// children still count toward progress through their parent's subIssues.
var issuesQuery = `query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    open: issues(first: 100, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) { nodes { ` + issueFields + ` } }
    closed: issues(first: 50, states: CLOSED, orderBy: {field: UPDATED_AT, direction: DESC}) { nodes { ` + issueFields + ` } }
  }
}`

type gqlIssue struct {
	Number    int        `json:"number"`
	Title     string     `json:"title"`
	URL       string     `json:"url"`
	State     string     `json:"state"`
	Body      string     `json:"body"`
	CreatedAt time.Time  `json:"createdAt"`
	UpdatedAt time.Time  `json:"updatedAt"`
	ClosedAt  *time.Time `json:"closedAt"`
	Labels    struct {
		Nodes []struct {
			Name string `json:"name"`
		} `json:"nodes"`
	} `json:"labels"`
	Parent *struct {
		Number int `json:"number"`
	} `json:"parent"`
	SubIssues struct {
		Nodes []IssueRef `json:"nodes"`
	} `json:"subIssues"`
	BlockedBy struct {
		Nodes []IssueRef `json:"nodes"`
	} `json:"blockedBy"`
	PRs struct {
		Nodes []PRRef `json:"nodes"`
	} `json:"closedByPullRequestsReferences"`
}

func runGH(write bool, args ...string) ([]byte, error) {
	cmd := exec.Command("gh", args...)
	cmd.Env = os.Environ()
	if write {
		cmd.Env = append(cmd.Env, "GHTKN_APP=write")
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return out, fmt.Errorf("gh %s: %v: %s", strings.Join(args[:min(2, len(args))], " "), err, strings.TrimSpace(stderr.String()))
	}
	return out, nil
}

func fetchIssues(repo string) (map[int]*Issue, error) {
	owner, name, ok := strings.Cut(repo, "/")
	if !ok {
		return nil, fmt.Errorf("repo must be owner/name: %q", repo)
	}
	out, err := runGH(false, "api", "graphql", "-f", "query="+issuesQuery, "-F", "owner="+owner, "-F", "name="+name)
	if err != nil {
		return nil, err
	}
	var resp struct {
		Data struct {
			Repository struct {
				Open   struct{ Nodes []gqlIssue } `json:"open"`
				Closed struct{ Nodes []gqlIssue } `json:"closed"`
			} `json:"repository"`
		} `json:"data"`
		Errors []struct {
			Message string `json:"message"`
		} `json:"errors"`
	}
	if err := json.Unmarshal(out, &resp); err != nil {
		return nil, fmt.Errorf("parse graphql response: %w", err)
	}
	if len(resp.Errors) > 0 {
		return nil, fmt.Errorf("graphql: %s", resp.Errors[0].Message)
	}
	issues := map[int]*Issue{}
	for _, list := range [][]gqlIssue{resp.Data.Repository.Open.Nodes, resp.Data.Repository.Closed.Nodes} {
		for _, g := range list {
			i := &Issue{
				Number: g.Number, Title: g.Title, URL: g.URL, State: g.State, Body: g.Body,
				CreatedAt: g.CreatedAt, UpdatedAt: g.UpdatedAt, ClosedAt: g.ClosedAt,
				SubIssues: g.SubIssues.Nodes, BlockedBy: g.BlockedBy.Nodes,
			}
			for _, p := range g.PRs.Nodes {
				if p.State != "CLOSED" {
					i.PRs = append(i.PRs, p)
				}
			}
			for _, l := range g.Labels.Nodes {
				i.Labels = append(i.Labels, l.Name)
			}
			if g.Parent != nil {
				i.Parent = g.Parent.Number
			}
			issues[i.Number] = i
		}
	}
	return issues, nil
}

func fetchIssueState(repo string, n int) (string, error) {
	out, err := runGH(false, "api", fmt.Sprintf("repos/%s/issues/%d", repo, n), "--jq", ".state")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}
