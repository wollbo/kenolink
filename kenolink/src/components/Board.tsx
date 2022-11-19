import React, { useState } from 'react';
import Square from "./Square";

type Props = {
    squares: Array<number>;

};
const Board: React.FC<Props> = (props) => {


    const [selectedNumbers, setselectedNumbers] = useState([]);




    const renderSquare = (i: number) => (


        <Square value={props.squares[i]} key={props.squares[i].toString()} setselectedNumbers={setselectedNumbers} selectedNumbers={selectedNumbers} />
    );

    const renderCols = (cols: number, value: number) => {
        const column_squares = [];
        for (let i = 0; i < cols; i++) {
            column_squares.push(renderSquare(i + value));
        }

        return (<div className="board-row" key={cols * value}> {column_squares}</div>);
    };

    const renderTable = (rows: number, columns: number) => {

        const column_rows = [];
        for (let i = 0; i < rows; i++) {
            column_rows.push(renderCols(columns, i * columns));
        }
        return column_rows
    };


    return (
        <div>
            {renderTable(7, 10)}
        </div>
    );
};

export default Board;