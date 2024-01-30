import { faker } from '@faker-js/faker'
import * as Fs from 'node:fs/promises'

// Number of users
const COUNT = 10

/**
 * @param {string} username 
 * @param {string} email 
 * @param {string} firstname 
 * @param {string} lastname 
 * @param {string} passwd 
 */
function tplCreateUser(username, firstname, lastname, email, passwd) {
  return `CALL _App.create_user('${username}', '${firstname}', '${lastname}', '${email}', '${passwd}', @__discarded__);`
}

/**
 * @param {number} ownerId 
 * @param {string} title 
 * @param {string} color 
 */
function tplCreateBoard(ownerId, title, color) {
  return `CALL _App.create_board(${ownerId}, '${title}', '${color}', @__discarded__);`
}

/**
 * @param {number} boardId 
 * @param {string} title 
 * @param {number} pos 
 */
function tplCreateColumn(boardId, title, pos) {
  return `INSERT INTO _App.Columns (boardId, title, pos) VALUE (${boardId}, '${title}', ${pos});`
}

/**
 * @param {number} userId 
 * @param {number} boardId 
 */
function tplCreateMember(userId, boardId) {
  return `INSERT INTO _App.Members (userId, boardId) VALUE (${userId}, ${boardId});`
}

/**
 * @param {number} columnId 
 * @param {number} authorId 
 * @param {number} pos 
 * @param {string} title 
 * @param {string} content 
 */
function tplCreateCard(columnId, authorId, pos, title, content) {
  return `INSERT INTO _App.Cards (columnId, authorId, pos, title, content)
    VALUE (${columnId}, ${authorId}, ${pos}, '${title}', '${content}');`
}

let lastBoardId = 0;

//////////////////
// LOOP-CEPTION //
//////////////////

// Making loop-into-loop is STRONGLY NOT RECOMMENDED but in this case, there no problems :)

async function createAll() {
  const list = []
  const endList = []
  
  for (let i = 1; i < COUNT + 1; i++) {
    list.push(tplCreateUser(
      faker.internet.userName(),
      faker.person.firstName(),
      faker.person.lastName(),
      faker.internet.email(),
      faker.internet.password({ length: 24 })
    ))

    list.push(tplCreateBoard(
      i,
      faker.string.alpha({ length: 30 }),
      faker.color.rgb()
    ))
    lastBoardId++

    for (let s = 1; s < COUNT + 1; s++) {
      if (s === i) continue
      endList.push(tplCreateMember(s, lastBoardId))
    }

    for (let j = 1; j < 4; j++) {
      list.push(tplCreateColumn(lastBoardId, faker.string.alpha({ length: 30 }), faker.number.int({ min: 0, max: 10 })))

      for (let k = 1; k < 7; k++) {
        if (k === i) continue
        endList.push(
          tplCreateCard(
            i,
            k,
            faker.number.int({ min: 0, max: 10 }),
            faker.string.alpha({ length: 30 }),
            faker.string.alpha({ length: 255 })
          )
        )
      }
    }
  }

  await Fs.writeFile('data.sql', [ ...list, ...endList ].join('\n'))
}

// Start
createAll()
  .then(() => console.log('Done!'))
  .catch(console.error)