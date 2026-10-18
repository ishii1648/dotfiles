import { execFile } from 'node:child_process'
import { join } from 'node:path'

// Orca starts plugin workers with only PATH and HOME, so board is called by
// the path configs/board/setup.sh installs it to.
const board = join(process.env.HOME ?? '', '.local', 'bin', 'board')

export default function activate(orca) {
  orca.commands.register(
    'open-control-room',
    () =>
      new Promise((resolve, reject) => {
        execFile(board, ['room'], (err, _stdout, stderr) =>
          err ? reject(new Error(stderr.trim() || err.message)) : resolve()
        )
      })
  )
}
